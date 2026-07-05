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
  console.error('❌ File .env tidak ditemukan');
  process.exit(1);
}

const SUPABASE_URL = envVars['SUPABASE_URL'];
const SUPABASE_KEY = envVars['SUPABASE_SERVICE_KEY'];
const TMDB_TOKEN = envVars['TMDB_READ_TOKEN'];

async function supabaseRequest(method, endpoint, body) {
  const headers = {
    'Content-Type': 'application/json',
    'apikey': SUPABASE_KEY,
    'Authorization': `Bearer ${SUPABASE_KEY}`,
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
      .replace(/&/g, 'and') // Ubah & menjadi and
      .replace(/[^a-z0-9]/g, '') // Hapus semua karakter lain
      .trim();
  };
  const target = clean(searchTitle);
  if (!target) return false;
  return clean(tmdbName) === target || (tmdbOriginalName && clean(tmdbOriginalName) === target);
}

async function main() {
  log("Fetching all series from Supabase...");
  const series = await supabaseRequest('GET', 'series?tmdb_id=not.is.null&select=id,slug,title,tmdb_id');
  if (!series || series.length === 0) {
    log("No series with tmdb_id found.");
    return;
  }

  log(`Found ${series.length} series with tmdb_id. Checking for corruption...`);
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
