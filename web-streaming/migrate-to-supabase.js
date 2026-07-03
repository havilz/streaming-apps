/**
 * migrate-to-supabase.js
 * Migrasi data dari SQLite lokal (dev.db) ke Supabase dengan schema normalized.
 * Mendukung resume — kalau putus di tengah, jalankan ulang dan lanjut dari posisi terakhir.
 *
 * Jalankan: node migrate-to-supabase.js
 */

import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';
import { readFileSync } from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// --- Load .env ---
const envVars = {};
try {
  const envContent = readFileSync(path.join(__dirname, '.env'), 'utf8');
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const [key, ...rest] = trimmed.split('=');
    if (key) envVars[key.trim()] = rest.join('=').trim();
  }
} catch {
  console.error('❌ File .env tidak ditemukan');
  process.exit(1);
}

const SUPABASE_URL = envVars['SUPABASE_URL'];
const SUPABASE_KEY = envVars['SUPABASE_SERVICE_KEY'];

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('❌ SUPABASE_URL atau SUPABASE_SERVICE_KEY tidak ada di .env');
  process.exit(1);
}

const BATCH = 50;
const DELAY = 400;
const sleep = ms => new Promise(r => setTimeout(r, ms));

// --- HTTP helper dengan retry ---
async function supabaseRequest(method, endpoint, body, retries = 4) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/${endpoint}`, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`,
          'Prefer': method === 'POST' ? 'resolution=merge-duplicates' : '',
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      if (!res.ok) {
        const err = await res.text();
        throw new Error(`[${method} /${endpoint}] ${res.status}: ${err}`);
      }
      const text = await res.text();
      return text ? JSON.parse(text) : null;
    } catch (err) {
      if (attempt === retries) throw err;
      await sleep(attempt * 2000);
    }
  }
}

const upsert = (table, rows) => supabaseRequest('POST', `${table}?on_conflict=id`, rows);

// --- Ambil jumlah row di tabel Supabase untuk resume ---
async function getSupabaseCount(table) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?select=count`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Prefer': 'count=exact',
      'Range': '0-0',
    },
  });
  const range = res.headers.get('content-range');
  return parseInt(range?.split('/')[1] ?? '0', 10);
}

// --- SQLite ---
const db = new Database(path.join(__dirname, 'dev.db'), { readonly: true });

// --- Cache referensi agar tidak query Supabase berulang ---
const genreCache = new Map();

function parseGenres(raw) {
  if (!raw) return [];
  try { return JSON.parse(raw).map(g => g.name).filter(Boolean); }
  catch { return []; }
}

function parseSeasons(raw) {
  if (!raw) return null;
  try {
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr.length : null;
  } catch { return null; }
}

async function getOrCreateGenre(name) {
  if (genreCache.has(name)) return genreCache.get(name);
  // Gunakan on_conflict=name agar tidak error kalau genre sudah ada
  await supabaseRequest('POST', 'genres?on_conflict=name', [{ name }]);
  const rows = await supabaseRequest('GET', `genres?name=eq.${encodeURIComponent(name)}&select=id`);
  const id = rows?.[0]?.id;
  genreCache.set(name, id);
  return id;
}

// ============================================================
// MIGRATE MOVIES
// ============================================================
async function migrateMovies() {
  const total = db.prepare("SELECT COUNT(*) as c FROM movies WHERE content_type = 'movie'").get().c;
  const existingCount = await getSupabaseCount('movies');
  const startOffset = Math.max(0, existingCount - BATCH);

  console.log(`\n📽  Movies: ${total} total | ${existingCount} sudah ada | mulai offset ${startOffset}`);

  let offset = startOffset, migrated = existingCount;

  while (offset < total) {
    const rows = db.prepare(`
      SELECT id, tmdb_id, imdb_id, title, slug, original_title,
             overview, poster_path, backdrop_path, release_date,
             runtime, vote_average, quality, genres
      FROM movies WHERE content_type = 'movie'
      ORDER BY created_at DESC
      LIMIT ${BATCH} OFFSET ${offset}
    `).all();

    if (!rows.length) break;

    await upsert('movies', rows.map(r => ({
      id: r.id,
      tmdb_id: r.tmdb_id ?? null,
      imdb_id: r.imdb_id ?? null,
      title: r.title,
      slug: r.slug,
      original_title: r.original_title ?? null,
      overview: r.overview ?? null,
      poster_path: r.poster_path ?? null,
      backdrop_path: r.backdrop_path ?? null,
      release_date: r.release_date ?? null,
      runtime: r.runtime ?? null,
      vote_average: r.vote_average ?? null,
      quality: r.quality ?? null,
    })));

    for (const r of rows) {
      for (const name of parseGenres(r.genres)) {
        const genreId = await getOrCreateGenre(name);
        if (genreId) await supabaseRequest('POST', 'movie_genres?on_conflict=movie_id,genre_id', [{ movie_id: r.id, genre_id: genreId }]);
      }
    }

    migrated += rows.length;
    offset += BATCH;
    process.stdout.write(`\r   ✓ ${migrated}/${total} (${Math.round(migrated / total * 100)}%)`);
    await sleep(DELAY);
  }

  console.log(`\n   ✅ Movies selesai`);
}

// ============================================================
// MIGRATE SERIES
// ============================================================
async function migrateSeries() {
  const total = db.prepare("SELECT COUNT(*) as c FROM movies WHERE content_type = 'series'").get().c;
  const existingCount = await getSupabaseCount('series');
  const startOffset = Math.max(0, existingCount - BATCH);

  console.log(`\n📺  Series: ${total} total | ${existingCount} sudah ada | mulai offset ${startOffset}`);

  let offset = startOffset, migrated = existingCount;

  while (offset < total) {
    const rows = db.prepare(`
      SELECT id, tmdb_id, imdb_id, title, slug, original_title,
             overview, poster_path, backdrop_path, release_date,
             vote_average, quality, genres, seasons
      FROM movies WHERE content_type = 'series'
      ORDER BY created_at DESC
      LIMIT ${BATCH} OFFSET ${offset}
    `).all();

    if (!rows.length) break;

    await upsert('series', rows.map(r => ({
      id: r.id,
      tmdb_id: r.tmdb_id ?? null,
      imdb_id: r.imdb_id ?? null,
      title: r.title,
      slug: r.slug,
      original_title: r.original_title ?? null,
      overview: r.overview ?? null,
      poster_path: r.poster_path ?? null,
      backdrop_path: r.backdrop_path ?? null,
      first_air_date: r.release_date ?? null,
      vote_average: r.vote_average ?? null,
      quality: r.quality ?? null,
      number_of_seasons: parseSeasons(r.seasons),
    })));

    for (const r of rows) {
      for (const name of parseGenres(r.genres)) {
        const genreId = await getOrCreateGenre(name);
        if (genreId) await supabaseRequest('POST', 'series_genres?on_conflict=series_id,genre_id', [{ series_id: r.id, genre_id: genreId }]);
      }
    }

    migrated += rows.length;
    offset += BATCH;
    process.stdout.write(`\r   ✓ ${migrated}/${total} (${Math.round(migrated / total * 100)}%)`);
    await sleep(DELAY);
  }

  console.log(`\n   ✅ Series selesai`);
}

// ============================================================
// MIGRATE EPISODES
// ============================================================
async function migrateEpisodes() {
  const total = db.prepare(`
    SELECT COUNT(*) as c FROM episodes e
    JOIN movies m ON e.movie_id = m.id
    WHERE m.content_type = 'series'
  `).get().c;

  const existingCount = await getSupabaseCount('episodes');
  const startOffset = Math.max(0, existingCount - BATCH);

  console.log(`\n🎬  Episodes: ${total} total | ${existingCount} sudah ada | mulai offset ${startOffset}`);

  let offset = startOffset, migrated = existingCount;

  while (offset < total) {
    const rows = db.prepare(`
      SELECT e.id, e.movie_id, e.season_number, e.episode_number,
             e.title, e.overview, e.still_path, e.runtime,
             e.air_date, e.video_url, e.video_type, e.video_fetched_at
      FROM episodes e
      JOIN movies m ON e.movie_id = m.id
      WHERE m.content_type = 'series'
      LIMIT ${BATCH} OFFSET ${offset}
    `).all();

    if (!rows.length) break;

    await upsert('episodes', rows.map(r => ({
      id: r.id,
      series_id: r.movie_id,
      season_number: r.season_number ?? 1,
      episode_number: r.episode_number ?? 1,
      title: r.title ?? null,
      overview: r.overview ?? null,
      still_path: r.still_path ?? null,
      runtime: r.runtime ?? null,
      air_date: r.air_date ?? null,
      video_url: r.video_url ?? null,
      video_type: r.video_type ?? 'unknown',
      video_fetched_at: r.video_fetched_at ?? null,
    })));

    migrated += rows.length;
    offset += BATCH;
    process.stdout.write(`\r   ✓ ${migrated}/${total} (${Math.round(migrated / total * 100)}%)`);
    await sleep(DELAY);
  }

  console.log(`\n   ✅ Episodes selesai`);
}

// ============================================================
// MAIN
// ============================================================
async function main() {
  console.log('🚀 Mulai migrasi SQLite → Supabase (schema normalized)');
  console.log(`   URL: ${SUPABASE_URL}\n`);
  const start = Date.now();

  try {
    await migrateMovies();
    await migrateSeries();
    await migrateEpisodes();
    console.log(`\n✅ Semua selesai dalam ${((Date.now() - start) / 1000).toFixed(1)} detik`);
  } catch (err) {
    console.error(`\n❌ Gagal: ${err.message}`);
    process.exit(1);
  } finally {
    db.close();
  }
}

main();
