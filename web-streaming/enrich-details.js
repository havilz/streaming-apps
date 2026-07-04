/**
 * enrich-details.js (Railway-compatible version)
 * Mengambil detail film yang masih kosong LANGSUNG dari Supabase,
 * tanpa bergantung pada SQLite lokal (dev.db).
 *
 * Film: dari TMDB /movie/{tmdb_id}
 * Series overview: dari idlix /api/series/{slug}
 *
 * Jalankan: node enrich-details.js
 * Opsi:     node enrich-details.js --type movies   (hanya film)
 *           node enrich-details.js --type series   (hanya series/overview)
 *           node enrich-details.js --limit 200     (batasi jumlah per run)
 */

import { gotScraping } from 'got-scraping';
import path from 'path';
import { fileURLToPath } from 'url';
import { readFileSync, existsSync } from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// --- Load .env (jika ada, untuk lokal) ---
const envVars = {};
const envPath = path.join(__dirname, '.env');
if (existsSync(envPath)) {
  try {
    const envContent = readFileSync(envPath, 'utf8');
    for (const line of envContent.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const [key, ...rest] = trimmed.split('=');
      if (key) envVars[key.trim()] = rest.join('=').trim();
    }
  } catch {
    // Abaikan error .env, gunakan process.env saja (Railway)
  }
}

// Prioritaskan environment variable dari Railway, fallback ke .env lokal
const SUPABASE_URL = process.env.SUPABASE_URL || envVars['SUPABASE_URL'];
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY || envVars['SUPABASE_SERVICE_KEY'];
const TMDB_TOKEN   = process.env.TMDB_READ_TOKEN || envVars['TMDB_READ_TOKEN'];
const BASE_URL     = process.env.IDLIX_BASE_URL || envVars['IDLIX_BASE_URL'] || 'https://z2.idlixku.com';

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('❌ SUPABASE_URL dan SUPABASE_SERVICE_KEY wajib diisi (env variable atau .env)');
  process.exit(1);
}
if (!TMDB_TOKEN) {
  console.error('❌ TMDB_READ_TOKEN tidak ditemukan. Dapatkan gratis di https://www.themoviedb.org/settings/api');
  process.exit(1);
}

// --- Parse args ---
const args = process.argv.slice(2);
const getArg = (name, def) => { const i = args.indexOf(name); return i !== -1 && args[i+1] ? args[i+1] : def; };
const TYPE  = getArg('--type', 'movies');
const LIMIT = parseInt(getArg('--limit', '100'), 10);
const DELAY = parseInt(getArg('--delay', '350'), 10);

const idlixHeaders = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
  Accept: 'application/json, text/plain, */*',
  Referer: `${BASE_URL}/`,
  Origin: BASE_URL,
};

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

// --- Supabase REST Helper ---
async function supabaseRequest(method, endpoint, body) {
  const url = `${SUPABASE_URL}/rest/v1/${endpoint}`;
  const res = await fetch(url, {
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
    const txt = await res.text();
    throw new Error(`Supabase [${method} ${endpoint}]: ${res.status} - ${txt}`);
  }
  const txt = await res.text();
  return txt ? JSON.parse(txt) : null;
}

// --- Fetch series detail dari IDLIX ---
async function fetchSeriesDetailIdlix(slug) {
  try {
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
    };
  } catch {
    return null;
  }
}

// --- Ekstrak judul & tahun dari slug ---
function parseSlug(slug) {
  // Contoh slug: "pirates-of-the-caribbean-2003" atau "the-batman-2022"
  const yearMatch = slug.match(/-(\d{4})$/);
  const year = yearMatch ? yearMatch[1] : null;
  const titleRaw = yearMatch ? slug.slice(0, -5) : slug;
  const title = titleRaw.replace(/-/g, ' ').trim();
  return { title, year };
}

// --- Cari TMDB ID berdasarkan judul dan tahun dari slug ---
async function searchTmdbId(slug) {
  const { title, year } = parseSlug(slug);
  const query = encodeURIComponent(title);
  const yearParam = year ? `&year=${year}` : '';
  try {
    const res = await fetch(
      `https://api.themoviedb.org/3/search/movie?query=${query}${yearParam}&language=en-US&page=1`,
      {
        headers: {
          'Authorization': `Bearer ${TMDB_TOKEN}`,
          'Accept': 'application/json',
        },
      }
    );
    if (!res.ok) return null;
    const data = await res.json();
    return data.results?.[0]?.id ?? null;
  } catch {
    return null;
  }
}

// --- Fetch movie detail dari TMDB (cari TMDB ID dulu jika null) ---
async function fetchMovieDetailTmdb(tmdbId, slug) {
  // Cari tmdb_id jika belum ada
  let resolvedId = tmdbId;
  if (!resolvedId && slug) {
    resolvedId = await searchTmdbId(slug);
  }
  if (!resolvedId) return null;
  try {
    const res = await fetch(`https://api.themoviedb.org/3/movie/${resolvedId}`, {
      headers: {
        'Authorization': `Bearer ${TMDB_TOKEN}`,
        'Accept': 'application/json',
      },
    });
    if (!res.ok) return null;
    const d = await res.json();
    return {
      tmdb_id:       resolvedId,
      overview:      d.overview      || null,
      backdrop_path: d.backdrop_path || null,
      runtime:       d.runtime       || null,
      release_date:  d.release_date  || null,
      vote_average:  d.vote_average  || null,
    };
  } catch {
    return null;
  }
}

// --- Ambil daftar konten yang perlu di-enrich dari Supabase ---
async function fetchUnenrichedItems() {
  if (TYPE === 'series') {
    // Series yang overviewnya masih null
    return await supabaseRequest(
      'GET',
      `series?select=id,slug,tmdb_id&overview=is.null&limit=${LIMIT}`
    );
  } else {
    // Movie yang overviewnya masih null
    return await supabaseRequest(
      'GET',
      `movies?select=id,slug,tmdb_id&overview=is.null&limit=${LIMIT}`
    );
  }
}

async function main() {
  console.log(`\n🚀 Enrich Details dimulai (type: ${TYPE}, limit: ${LIMIT})`);
  console.log(`   Mengambil daftar konten yang belum ter-enrich dari Supabase...`);

  const items = await fetchUnenrichedItems();

  if (!items || items.length === 0) {
    console.log(`\n✅ Semua konten bertipe '${TYPE}' sudah ter-enrich. Tidak ada yang perlu diproses.`);
    return 0;
  }

  console.log(`\n🔍 ${items.length} konten perlu di-enrich\n`);

  let success = 0, failed = 0;

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const label = item.slug?.substring(0, 40)?.padEnd(40) ?? item.id;
    process.stdout.write(`\r[${i+1}/${items.length}] ${label} ✓${success} ✗${failed}`);

    try {
      let raw;
      if (TYPE === 'series') {
        raw = await fetchSeriesDetailIdlix(item.slug);
      } else {
        raw = await fetchMovieDetailTmdb(item.tmdb_id, item.slug);
      }

      if (!raw) {
        failed++;
        await sleep(DELAY);
        continue;
      }

      // Hapus key null agar tidak menimpa data yang sudah ada
      const patch = Object.fromEntries(Object.entries(raw).filter(([, v]) => v !== null));
      if (Object.keys(patch).length === 0) {
        success++;
        continue;
      }

      const table = TYPE === 'series' ? 'series' : 'movies';
      await supabaseRequest('PATCH', `${table}?id=eq.${encodeURIComponent(item.id)}`, patch);
      success++;
    } catch (err) {
      failed++;
      process.stdout.write(`\n   ⚠️  Error: ${err.message}\n`);
    }

    await sleep(DELAY);
  }

  console.log(`\n\n✅ Selesai: ${success} berhasil, ${failed} gagal dari ${items.length} total`);
  return items.length;
}

main().catch(err => {
  console.error('\n❌ Fatal error:', err.message);
  process.exit(1);
});
