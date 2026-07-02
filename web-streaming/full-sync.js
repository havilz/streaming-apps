/**
 * full-sync.js — Script sinkronisasi penuh konten dari idlix ke SQLite lokal
 * 
 * Jalankan: node full-sync.js [--type movies|series|all] [--from-page N] [--to-page N] [--batch-delay MS]
 * 
 * Contoh:
 *   node full-sync.js                          → Sync semua movies + series
 *   node full-sync.js --type movies            → Hanya movies
 *   node full-sync.js --type series            → Hanya series
 *   node full-sync.js --from-page 50           → Mulai dari halaman 50
 *   node full-sync.js --type movies --to-page 100  → Movies halaman 1-100
 */

import Database from "better-sqlite3";
import { gotScraping } from "got-scraping";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_PATH = path.join(__dirname, "dev.db");
const BASE_URL = process.env.IDLIX_BASE_URL || "https://z2.idlixku.com";

// --- Parse CLI args ---
const args = process.argv.slice(2);
function getArg(name, defaultVal) {
  const idx = args.indexOf(name);
  return idx !== -1 && args[idx + 1] ? args[idx + 1] : defaultVal;
}
const TYPE = getArg("--type", "all");           // movies | series | all
const FROM_PAGE = parseInt(getArg("--from-page", "1"), 10);
const TO_PAGE = parseInt(getArg("--to-page", "0"), 10);    // 0 = all pages
const BATCH_DELAY = parseInt(getArg("--batch-delay", "200"), 10); // ms between requests

// --- Setup DB ---
const db = new Database(DB_PATH);
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

const insertMovie = db.prepare(`
  INSERT INTO movies (
    id, title, slug, poster_path, backdrop_path,
    content_type, release_date, runtime, vote_average, genres, quality, country
  ) VALUES (
    @id, @title, @slug, @poster_path, @backdrop_path,
    @content_type, @release_date, @runtime, @vote_average, @genres, @quality, @country
  )
  ON CONFLICT(id) DO UPDATE SET
    country = excluded.country,
    release_date = excluded.release_date,
    vote_average = excluded.vote_average
`);

const insertEpisode = db.prepare(`
  INSERT OR IGNORE INTO episodes (id, movie_id, season_number, episode_number, title)
  VALUES (@id, @movie_id, 1, 1, @title)
`);

const syncPageItems = db.transaction((items, contentType) => {
  let inserted = 0;
  let skipped = 0;
  for (const item of items) {
    const voteAverage = item.voteAverage != null ? parseFloat(String(item.voteAverage)) : null;
    const releaseDate = item.releaseDate ?? item.firstAirDate ?? null;

    const r = insertMovie.run({
      id: item.id,
      title: item.title,
      slug: item.slug,
      poster_path: item.posterPath ?? null,
      backdrop_path: item.backdropPath ?? null,
      content_type: contentType,
      release_date: releaseDate,
      runtime: item.runtime ?? null,
      vote_average: voteAverage,
      genres: item.genres ? JSON.stringify(item.genres) : null,
      quality: item.quality ?? null,
      country: item.country ?? null,
    });

    if (r.changes > 0) {
      inserted++;
      // For movies, create playable episode entry
      if (contentType === "movie") {
        insertEpisode.run({ id: item.id, movie_id: item.id, title: item.title });
      }
    } else {
      skipped++;
    }
  }
  return { inserted, skipped };
});

// --- HTTP headers ---
const headers = {
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "en-US,en;q=0.9,id;q=0.8",
  Referer: `${BASE_URL}/`,
  Origin: BASE_URL,
};

async function fetchPage(endpoint, page) {
  const res = await gotScraping({
    url: `${BASE_URL}/api/${endpoint}?page=${page}&limit=24`,
    headers,
    useHeaderGenerator: false,
  });
  if (res.statusCode !== 200) throw new Error(`HTTP ${res.statusCode}`);
  return JSON.parse(res.body);
}

async function syncType(endpoint, contentType) {
  // Get page 1 to know total pages
  const firstPage = await fetchPage(endpoint, FROM_PAGE);
  const totalPages = TO_PAGE > 0
    ? Math.min(TO_PAGE, firstPage.pagination.totalPages)
    : firstPage.pagination.totalPages;

  console.log(`\n📦 [${contentType.toUpperCase()}] ${firstPage.pagination.total} items across ${firstPage.pagination.totalPages} pages`);
  console.log(`   → Syncing pages ${FROM_PAGE}–${totalPages}...\n`);

  let totalInserted = 0;
  let totalSkipped = 0;
  let failed = 0;

  // First page already fetched
  const r0 = syncPageItems(firstPage.data, contentType);
  totalInserted += r0.inserted;
  totalSkipped += r0.skipped;
  process.stdout.write(`  Page ${FROM_PAGE}/${totalPages}: +${r0.inserted} new, ${r0.skipped} existing\n`);

  for (let page = FROM_PAGE + 1; page <= totalPages; page++) {
    try {
      await new Promise(r => setTimeout(r, BATCH_DELAY));
      const data = await fetchPage(endpoint, page);
      const r = syncPageItems(data.data, contentType);
      totalInserted += r.inserted;
      totalSkipped += r.skipped;

      // Progress update every 10 pages
      if (page % 10 === 0 || page === totalPages) {
        process.stdout.write(`  Page ${page}/${totalPages}: +${r.inserted} new | Total: ${totalInserted} inserted, ${totalSkipped} existing\n`);
      }
    } catch (err) {
      failed++;
      console.error(`  ⚠️  Page ${page} failed: ${err.message}`);
    }
  }

  const totalInDb = db.prepare("SELECT COUNT(*) as c FROM movies WHERE content_type = ?").get(contentType);
  console.log(`\n✅ [${contentType.toUpperCase()}] Done!`);
  console.log(`   Inserted: ${totalInserted} | Skipped: ${totalSkipped} | Errors: ${failed}`);
  console.log(`   Total ${contentType} in DB: ${totalInDb.c}`);
}

async function main() {
  const startTime = Date.now();
  console.log("=".repeat(60));
  console.log("🎬 StreamVault — Full Content Sync");
  console.log(`   Type: ${TYPE} | Pages: ${FROM_PAGE}–${TO_PAGE || "all"} | Delay: ${BATCH_DELAY}ms`);
  console.log("=".repeat(60));

  if (TYPE === "movies" || TYPE === "all") {
    await syncType("movies", "movie");
  }

  if (TYPE === "series" || TYPE === "all") {
    await syncType("series", "series");
  }

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  const totalInDb = db.prepare("SELECT COUNT(*) as c FROM movies").get();
  console.log("\n" + "=".repeat(60));
  console.log(`🏁 All done in ${elapsed}s | Total in DB: ${totalInDb.c}`);
  console.log("=".repeat(60));
  db.close();
}

main().catch(err => {
  console.error("Fatal error:", err);
  process.exit(1);
});
