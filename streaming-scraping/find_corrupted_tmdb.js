import { readFileSync, writeFileSync, appendFileSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const logFile = path.join(__dirname, 'find_corrupted_tmdb.log');
// Bersihkan log lama di awal
writeFileSync(logFile, `=== START CHECK: ${new Date().toLocaleString()} ===\n`);

function log(msg) {
  console.log(msg);
  appendFileSync(logFile, msg + '\n');
}

// Load .env
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
  // Abaikan error jika .env tidak ada (misalnya saat berjalan di Railway)
}

const SUPABASE_URL = process.env.SUPABASE_URL || envVars['SUPABASE_URL'];
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY || envVars['SUPABASE_SERVICE_KEY'];
const TMDB_TOKEN = process.env.TMDB_READ_TOKEN || envVars['TMDB_READ_TOKEN'];

if (!SUPABASE_URL || !SUPABASE_KEY || !TMDB_TOKEN) {
  console.error('❌ SUPABASE_URL, SUPABASE_SERVICE_KEY, dan TMDB_READ_TOKEN wajib diisi.');
  process.exit(1);
}

async function supabaseRequest(method, endpoint, body, extraHeaders = {}) {
  const headers = {
    'Content-Type': 'application/json',
    'apikey': SUPABASE_KEY,
    'Authorization': `Bearer ${SUPABASE_KEY}`,
    ...extraHeaders,
  };
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${endpoint}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  if (res.status === 204) return null;
  return res.json();
}

async function fetchTmdbDetail(tmdbId) {
  try {
    const res = await fetch(`https://api.themoviedb.org/3/tv/${tmdbId}?language=en-US`, {
      headers: {
        'Authorization': `Bearer ${TMDB_TOKEN}`,
        'Accept': 'application/json',
      },
    });
    if (!res.ok) return null;
    return res.json();
  } catch {
    return null;
  }
}

function parseSlug(slug) {
  const yearMatch = slug.match(/-([0-9]{4})$/);
  const year = yearMatch ? yearMatch[1] : null;
  const title = slug
    .replace(/-[0-9]{4}$/, '')
    .replace(/-/g, ' ');
  return { title, year };
}
function isTitleMatch(searchTitle, tmdbName, tmdbOriginalName) {
  const clean = (s) => {
    if (!s) return '';
    return s.normalize('NFD') // Hapus aksen (diacritics)
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/ø/g, 'o')
      .replace(/æ/g, 'ae')
      .replace(/å/g, 'a')
      .replace(/ß/g, 'ss')
      .replace(/ä/g, 'a')
      .replace(/ö/g, 'o')
      .replace(/ü/g, 'u')
      .replace(/&/g, 'and') // Ubah & menjadi and
      .replace(/[^a-z0-9]/g, '') // Hapus semua karakter lain
      .trim();
  };

  const target = clean(searchTitle);
  if (!target) return false;

  const tName = clean(tmdbName);
  const tOrg = tmdbOriginalName ? clean(tmdbOriginalName) : '';

  // 1. Match langsung
  if (target === tName || (tOrg && target === tOrg)) {
    return true;
  }

  // 2. Cek pemisahan karakter seperti titik dua (:), strip (-), atau pipe (|)
  const parts = searchTitle.split(/[:\-|]/).map(p => clean(p.trim())).filter(p => p.length > 2);
  for (const part of parts) {
    if (part === tName || (tOrg && part === tOrg)) {
      return true;
    }
  }

  // Cek pemisahan dari sisi TMDB juga (misal TMDB: "Ooku: The Inner Chambers", searchTitle: "Ooku")
  const tmdbParts = tmdbName.split(/[:\-|]/).map(p => clean(p.trim())).filter(p => p.length > 2);
  for (const part of tmdbParts) {
    if (part === target) {
      return true;
    }
  }
  if (tmdbOriginalName) {
    const tmdbOrgParts = tmdbOriginalName.split(/[:\-|]/).map(p => clean(p.trim())).filter(p => p.length > 2);
    for (const part of tmdbOrgParts) {
      if (part === target) {
        return true;
      }
    }
  }

  return false;
}

async function main() {
  log("Fetching all series from Supabase with pagination...");
  let series = [];
  let page = 0;
  const pageSize = 1000;

  while (true) {
    const start = page * pageSize;
    const end = start + pageSize - 1;
    log(`Fetching page ${page + 1} (range ${start}-${end})...`);
    const pageSeries = await supabaseRequest(
      'GET',
      'series?tmdb_id=not.is.null&select=id,slug,title,tmdb_id',
      null,
      { 'Range': `${start}-${end}` }
    );
    if (!pageSeries || pageSeries.length === 0) break;
    series = series.concat(pageSeries);
    if (pageSeries.length < pageSize) break;
    page++;
  }

  if (series.length === 0) {
    log("No series with tmdb_id found.");
    return;
  }

  log(`Found ${series.length} total series with tmdb_id. Checking for corruption...`);
  let corruptedCount = 0;

  for (const s of series) {
    const tmdbId = s.tmdb_id;
    const { title } = parseSlug(s.slug);
    const tmdbDetail = await fetchTmdbDetail(tmdbId);
    if (!tmdbDetail) {
      log(`⚠️  Series "${s.title}" (slug: ${s.slug}, TMDB ID: ${tmdbId}): TMDB returned no details. Resetting tmdb_id to null.`);
      await supabaseRequest('PATCH', `series?id=eq.${s.id}`, { tmdb_id: null });
      corruptedCount++;
      continue;
    }

    const matches = isTitleMatch(title, tmdbDetail.name, tmdbDetail.original_name);
    if (!matches) {
      log(`❌ CORRUPTED: Series "${s.title}" (slug: ${s.slug}) has TMDB ID ${tmdbId} which belongs to "${tmdbDetail.name}" (Original: "${tmdbDetail.original_name}"). Resetting tmdb_id, status, overview, number_of_seasons...`);
      await supabaseRequest('PATCH', `series?id=eq.${s.id}`, {
        tmdb_id: null,
        status: null,
        overview: null,
        number_of_seasons: null,
      });

      log(`   -> Deleting incorrect episodes for series "${s.title}"...`);
      await supabaseRequest('DELETE', `episodes?series_id=eq.${s.id}`);
      corruptedCount++;
    } else {
      log(`✅ MATCH: "${s.title}" matches "${tmdbDetail.name}"`);
    }
    await new Promise(r => setTimeout(r, 200));
  }

  log(`\nDone. Cleaned ${corruptedCount} corrupted series.`);
}

main().catch(console.error);
