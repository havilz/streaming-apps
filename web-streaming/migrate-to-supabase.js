/**
 * migrate-to-supabase.js
 * Migrasi data dari SQLite lokal (dev.db) ke Supabase PostgreSQL.
 *
 * Jalankan: node migrate-to-supabase.js
 *
 * Pastikan .env sudah berisi SUPABASE_URL dan SUPABASE_SERVICE_KEY
 * (gunakan service_role key, bukan anon key — agar bisa bypass RLS)
 */

import Database from "better-sqlite3";
import path from "path";
import { fileURLToPath } from "url";
import { readFileSync } from "fs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// --- Load .env manual (tanpa dotenv dependency) ---
const envPath = path.join(__dirname, ".env");
const envVars = {};
try {
  const envContent = readFileSync(envPath, "utf8");
  for (const line of envContent.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const [key, ...rest] = trimmed.split("=");
    if (key) envVars[key.trim()] = rest.join("=").trim();
  }
} catch {
  console.error("❌ File .env tidak ditemukan");
  process.exit(1);
}

const SUPABASE_URL = envVars["SUPABASE_URL"];
const SUPABASE_KEY = envVars["SUPABASE_SERVICE_KEY"];

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error("❌ SUPABASE_URL atau SUPABASE_SERVICE_KEY tidak ditemukan di .env");
  console.error("   Tambahkan SUPABASE_SERVICE_KEY (service_role key) ke file .env website");
  process.exit(1);
}

// --- Helper: upsert ke Supabase via REST API ---
async function upsert(table, rows) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": SUPABASE_KEY,
      "Authorization": `Bearer ${SUPABASE_KEY}`,
      "Prefer": "resolution=merge-duplicates",
    },
    body: JSON.stringify(rows),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Supabase error on ${table}: ${res.status} — ${err}`);
  }
}

// --- Koneksi ke SQLite ---
const DB_PATH = path.join(__dirname, "dev.db");
let db;
try {
  db = new Database(DB_PATH, { readonly: true });
} catch {
  console.error(`❌ dev.db tidak ditemukan di: ${DB_PATH}`);
  process.exit(1);
}

const BATCH_SIZE = 200; // jumlah row per request ke Supabase

async function migrateMovies() {
  const total = db.prepare("SELECT COUNT(*) as count FROM movies").get().count;
  console.log(`\n📽  Migrasi movies: ${total} baris`);

  let offset = 0;
  let migrated = 0;

  while (offset < total) {
    const rows = db.prepare(`
      SELECT
        id, tmdb_id, imdb_id, title, slug, original_title,
        overview, tagline, poster_path, backdrop_path, logo_path,
        content_type, release_date, runtime, vote_average,
        genres, quality, seasons
      FROM movies
      LIMIT ${BATCH_SIZE} OFFSET ${offset}
    `).all();

    if (rows.length === 0) break;

    await upsert("movies", rows);
    migrated += rows.length;
    offset += BATCH_SIZE;

    const pct = Math.round((migrated / total) * 100);
    process.stdout.write(`\r   ✓ ${migrated}/${total} (${pct}%)`);
  }

  console.log(`\n   Selesai: ${migrated} movies berhasil dimigrasikan`);
}

async function migrateEpisodes() {
  const total = db.prepare("SELECT COUNT(*) as count FROM episodes").get().count;
  console.log(`\n📺  Migrasi episodes: ${total} baris`);

  let offset = 0;
  let migrated = 0;

  while (offset < total) {
    const rows = db.prepare(`
      SELECT
        id, movie_id, season_number, episode_number,
        title, overview, still_path, runtime,
        air_date, video_url, video_type, video_fetched_at
      FROM episodes
      LIMIT ${BATCH_SIZE} OFFSET ${offset}
    `).all();

    if (rows.length === 0) break;

    await upsert("episodes", rows);
    migrated += rows.length;
    offset += BATCH_SIZE;

    const pct = Math.round((migrated / total) * 100);
    process.stdout.write(`\r   ✓ ${migrated}/${total} (${pct}%)`);
  }

  console.log(`\n   Selesai: ${migrated} episodes berhasil dimigrasikan`);
}

// --- Main ---
async function main() {
  console.log("🚀 Mulai migrasi SQLite → Supabase");
  console.log(`   URL: ${SUPABASE_URL}`);

  const startTime = Date.now();

  try {
    await migrateMovies();
    await migrateEpisodes();

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`\n✅ Migrasi selesai dalam ${elapsed} detik`);
  } catch (err) {
    console.error(`\n❌ Migrasi gagal: ${err.message}`);
    process.exit(1);
  } finally {
    db.close();
  }
}

main();
