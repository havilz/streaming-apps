/**
 * enrich-details.js
 * Mengambil detail lengkap (overview, seasons, backdrop, dll) per konten:
 * - Series: dari idlix /api/series/{slug}
 * - Movies: dari TMDB /movie/{tmdb_id} (gratis, tidak butuh bypass)
 *
 * Jalankan: node enrich-details.js
 * Opsi:     node enrich-details.js --type movies   (hanya film)
 *           node enrich-details.js --type series   (hanya series)
 *           node enrich-details.js --limit 100     (batasi jumlah)
 */

import Database from 'better-sqlite3';
import { gotScraping } from 'got-scraping';
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
const TMDB_TOKEN   = envVars['TMDB_READ_TOKEN'];
const BASE_URL     = envVars['IDLIX_BASE_URL'] || 'https://z2.idlixku.com';

if (!TMDB_TOKEN) {
  console.error('❌ TMDB_READ_TOKEN tidak ditemukan di .env');
  console.error('   Dapatkan gratis di https://www.themoviedb.org/settings/api');
  console.error('   Tambahkan: TMDB_READ_TOKEN=eyJhbGci... ke file .env website');
  process.exit(1);
}

// --- Parse args ---
const args = process.argv.slice(2);
const getArg = (name, def) => { const i = args.indexOf(name); return i !== -1 && args[i+1] ? args[i+1] : def; };
const TYPE  = getArg('--type', 'all');
const LIMIT = parseInt(getArg('--limit', '0'), 10);
const DELAY = parseInt(getArg('--delay', '300'), 10);

// --- SQLite ---
const db = new Database(path.join(__dirname, 'dev.db'));
db.pragma('journal_mode = WAL');

const updateSQLite = db.prepare(`
  UPDATE movies SET
    overview      = COALESCE(@overview, overview),
    tagline       = COALESCE(@tagline, tagline),
    backdrop_path = COALESCE(@backdrop_path, backdrop_path),
    logo_path     = COALESCE(@logo_path, logo_path),
    runtime       = COALESCE(@runtime, runtime),
    seasons       = COALESCE(@seasons, seasons),
    updated_at    = datetime('now')
  WHERE id = @id
`);

const idlixHeaders = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
  Accept: 'application/json, text/plain, */*',
  Referer: `${BASE_URL}/`,
  Origin: BASE_URL,
};

// --- Fetch series detail dari idlix ---
async function fetchSeriesDetail(slug) {
  const res = await gotScraping({
    url: `${BASE_URL}/api/series/${slug}`,
    headers: idlixHeaders,
    useHeaderGenerator: false,
  });
  if (res.statusCode !== 200) return null;
  const d = JSON.parse(res.body);
  return {
    overview:      d.overview      ?? null,
    tagline:       d.tagline       ?? null,
    backdrop_path: d.backdropPath  ?? null,
    logo_path:     d.logoPath      ?? null,
    runtime:       null,
    seasons: d.seasons?.length
      ? JSON.stringify(d.seasons.map(s => ({
          id: s.id,
          seasonNumber: s.seasonNumber,
          name: s.name || `Season ${s.seasonNumber}`,
          episodeCount: s.episodeCount,
        })))
      : null,
  };
}

// --- Fetch movie detail dari TMDB ---
async function fetchMovieDetail(tmdbId) {
  if (!tmdbId) return null;
  const res = await fetch(`https://api.themoviedb.org/3/movie/${tmdbId}`, {
    headers: {
      'Authorization': `Bearer ${TMDB_TOKEN}`,
      'Accept': 'application/json',
    },
  });
  if (!res.ok) return null;
  const d = await res.json();
  return {
    overview:      d.overview      || null,
    tagline:       d.tagline       || null,
    backdrop_path: d.backdrop_path || null,
    logo_path:     null,
    runtime:       d.runtime       || null,
    seasons:       null,
  };
}

// --- Upsert ke Supabase ---
async function upsertSupabase(id, patch) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/movies?id=eq.${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
    },
    body: JSON.stringify(patch),
  });
  if (!res.ok) throw new Error(`Supabase error: ${res.status} ${await res.text()}`);
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

async function main() {
  let whereClause = "(overview IS NULL OR overview = '')";
  if (TYPE === 'movies') whereClause += " AND content_type = 'movie'";
  if (TYPE === 'series') whereClause += " AND content_type = 'series'";

  let query = `SELECT id, slug, content_type, tmdb_id FROM movies WHERE ${whereClause} ORDER BY created_at DESC`;
  if (LIMIT > 0) query += ` LIMIT ${LIMIT}`;

  const items = db.prepare(query).all();
  console.log(`\n🔍 ${items.length} konten perlu di-enrich (type: ${TYPE})\n`);
  if (items.length === 0) return;

  let success = 0, failed = 0;

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const isMovie = item.content_type === 'movie';
    process.stdout.write(`\r[${i+1}/${items.length}] ${item.slug.substring(0,35).padEnd(35)} ✓${success} ✗${failed}`);

    try {
      const raw = isMovie
        ? await fetchMovieDetail(item.tmdb_id)
        : await fetchSeriesDetail(item.slug);

      if (!raw) { failed++; await sleep(DELAY); continue; }

      // Hapus key null agar tidak overwrite data yang sudah ada
      const patch = Object.fromEntries(Object.entries(raw).filter(([,v]) => v !== null));
      if (Object.keys(patch).length === 0) { success++; continue; }

      updateSQLite.run({ id: item.id, overview: null, tagline: null, backdrop_path: null, logo_path: null, runtime: null, seasons: null, ...patch });
      await upsertSupabase(item.id, patch);
      success++;
    } catch {
      failed++;
    }

    await sleep(DELAY);
  }

  console.log(`\n\n✅ Selesai: ${success} berhasil, ${failed} gagal`);
}

main().catch(err => { console.error('\n❌', err.message); process.exit(1); });
