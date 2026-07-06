/**
 * sync_ongoing_local.js
 * ==========================================
 * Sinkronisasi data series ongoing (Returning Series) secara lokal.
 * Dapat digunakan untuk sinkronisasi massal seluruh series ongoing tanpa batas waktu 150 detik,
 * atau untuk memperbarui series tertentu menggunakan parameter --slug.
 *
 * Contoh penggunaan:
 *   1. Update semua series ongoing secara bergiliran:
 *      node sync_ongoing_local.js
 *   2. Update series spesifik berdasarkan slug:
 *      node sync_ongoing_local.js --slug that-time-i-got-reincarnated-as-a-slime-2018
 */

import { gotScraping } from 'got-scraping';
import path from 'path';
import { fileURLToPath } from 'url';
import { readFileSync, existsSync } from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// --- Load env ---
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
  } catch {}
}

const SUPABASE_URL = process.env.SUPABASE_URL || envVars['SUPABASE_URL'];
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY || envVars['SUPABASE_SERVICE_KEY'];
const TMDB_TOKEN   = process.env.TMDB_READ_TOKEN || envVars['TMDB_READ_TOKEN'];
const BASE_URL     = process.env.IDLIX_BASE_URL || envVars['IDLIX_BASE_URL'] || 'https://z2.idlixku.com';

if (!SUPABASE_URL || !SUPABASE_KEY || !TMDB_TOKEN) {
  console.error('❌ SUPABASE_URL, SUPABASE_SERVICE_KEY, dan TMDB_READ_TOKEN wajib diisi!');
  process.exit(1);
}

const idlixHeaders = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
  Accept: 'application/json, text/plain, */*',
  Referer: `${BASE_URL}/`,
  Origin: BASE_URL,
};

const COUNTRY_MAP = {
  'US': 'United States', 'KR': 'South Korea', 'JP': 'Japan', 'CN': 'China',
  'ID': 'Indonesia', 'GB': 'United Kingdom', 'FR': 'France', 'DE': 'Germany',
  'IT': 'Italy', 'ES': 'Spain', 'CA': 'Canada', 'AU': 'Australia',
  'IN': 'India', 'TH': 'Thailand', 'PH': 'Philippines', 'MY': 'Malaysia',
  'TW': 'Taiwan', 'HK': 'Hong Kong', 'SG': 'Singapore', 'VN': 'Vietnam'
};

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

async function supabaseRequest(method, endpoint, body, extraHeaders = {}) {
  const url = `${SUPABASE_URL}/rest/v1/${endpoint}`;
  const res = await fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Prefer': method === 'POST' ? 'resolution=merge-duplicates' : '',
      ...extraHeaders,
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

async function fetchSeriesDetail(slug) {
  try {
    const res = await gotScraping({
      url: `${BASE_URL}/api/series/${slug}`,
      headers: idlixHeaders,
    });
    if (res.statusCode === 200) return JSON.parse(res.body);
  } catch (err) {
    console.warn(`   ⚠️ Gagal mengambil detail IDLIX untuk ${slug}: ${err.message}`);
  }
  return null;
}

async function fetchEpisodes(slug, seasonNo) {
  try {
    const res = await gotScraping({
      url: `${BASE_URL}/api/series/${slug}/season/${seasonNo}`,
      headers: idlixHeaders,
    });
    if (res.statusCode === 200) {
      const data = JSON.parse(res.body);
      return data.season?.episodes ?? [];
    }
  } catch (err) {
    console.warn(`   ⚠️ Gagal mengambil episode S${seasonNo} untuk ${slug}: ${err.message}`);
  }
  return [];
}

async function fetchTmdbDetail(tmdbId) {
  if (!tmdbId) return null;
  try {
    const res = await fetch(`https://api.themoviedb.org/3/tv/${tmdbId}`, {
      headers: {
        'Authorization': `Bearer ${TMDB_TOKEN}`,
        'Accept': 'application/json',
      },
    });
    if (res.ok) return res.json();
  } catch (err) {
    console.warn(`   ⚠️ Gagal mengambil detail TMDB ID ${tmdbId}: ${err.message}`);
  }
  return null;
}

// Helper caching references
const genreCache = new Map();
const countryCache = new Map();
const networkCache = new Map();

async function getOrCreateGenre(name) {
  if (genreCache.has(name)) return genreCache.get(name);
  const res = await supabaseRequest(
    'POST',
    'genres?on_conflict=name&select=id',
    { name },
    { 'Prefer': 'resolution=merge-duplicates, return=representation' }
  );
  const id = res?.[0]?.id ?? null;
  if (id) genreCache.set(name, id);
  return id;
}

async function getOrCreateCountry(code, name) {
  const key = `${code}:${name}`;
  if (countryCache.has(key)) return countryCache.get(key);
  const res = await supabaseRequest(
    'POST',
    'countries?on_conflict=name&select=id',
    { code, name },
    { 'Prefer': 'resolution=merge-duplicates, return=representation' }
  );
  const id = res?.[0]?.id ?? null;
  if (id) countryCache.set(key, id);
  return id;
}

async function getOrCreateNetwork(name, logoPath) {
  if (networkCache.has(name)) return networkCache.get(name);
  const res = await supabaseRequest(
    'POST',
    'networks?on_conflict=name&select=id',
    { name, logo_path: logoPath },
    { 'Prefer': 'resolution=merge-duplicates, return=representation' }
  );
  const id = res?.[0]?.id ?? null;
  if (id) networkCache.set(name, id);
  return id;
}

async function main() {
  const args = process.argv.slice(2);
  let targetSlug = null;
  const slugIdx = args.indexOf('--slug');
  if (slugIdx !== -1 && args[slugIdx + 1]) {
    targetSlug = args[slugIdx + 1];
  }

  let seriesList = [];
  if (targetSlug) {
    console.log(`🔍 Mencari series spesifik dengan slug: ${targetSlug}`);
    seriesList = await supabaseRequest('GET', `series?slug=eq.${targetSlug}&select=id,slug,number_of_seasons,status,tmdb_id,title`);
  } else {
    console.log("🔍 Mengambil daftar series ongoing (Returning Series) terlama dari Supabase...");
    seriesList = await supabaseRequest(
      'GET',
      'series?or=(status.eq.Returning%20Series,status.is.null,number_of_seasons.is.null)&order=updated_at.asc&limit=50&select=id,slug,number_of_seasons,status,tmdb_id,title'
    );
  }

  console.log(` Ditemukan ${seriesList.length} series untuk diproses.\n`);

  let successCount = 0;
  for (let i = 0; i < seriesList.length; i++) {
    const series = seriesList[i];
    console.log(`[${i + 1}/${seriesList.length}] Memproses series: ${series.title} (${series.slug})`);

    const detail = await fetchSeriesDetail(series.slug);
    if (!detail) {
      console.warn(`   ❌ Melewati ${series.slug} karena gagal fetch detail dari IDLIX.`);
      // Sentuh baris agar updated_at bergeser ke sekarang (rotasi antrean)
      await supabaseRequest('PATCH', `series?id=eq.${series.id}`, { status: series.status });
      continue;
    }

    const tmdbId = detail.tmdbId ?? series.tmdb_id ?? null;
    let overview = detail.overview ?? null;
    let status = detail.status ?? null;
    let countriesList = [];
    let networksList = [];

    // TMDB Enrichment
    if (tmdbId) {
      const tmdbDetail = await fetchTmdbDetail(tmdbId);
      if (tmdbDetail) {
        overview = tmdbDetail.overview || overview;
        status = tmdbDetail.status || status;
        if (tmdbDetail.production_countries) {
          countriesList = tmdbDetail.production_countries.map(c => ({
            code: c.iso_3166_1,
            name: c.name
          }));
        }
        if (tmdbDetail.networks) {
          networksList = tmdbDetail.networks.map(n => ({
            name: n.name,
            logoPath: n.logo_path || null
          }));
        }
      }
    }

    // Fallback countries
    if (countriesList.length === 0 && detail.country) {
      const countryCode = detail.country;
      const countryName = COUNTRY_MAP[countryCode.toUpperCase()] ?? countryCode;
      countriesList.push({ code: countryCode, name: countryName });
    }

    // Fallback networks
    if (networksList.length === 0 && detail.networks) {
      networksList = detail.networks.map(n => ({
        name: n.name,
        logoPath: n.logoPath ?? n.logo_path ?? null
      }));
    }

    // Link countries
    const countryIds = [];
    for (const c of countriesList) {
      const cId = await getOrCreateCountry(c.code, c.name);
      if (cId) countryIds.push(cId);
    }
    const countryLinks = countryIds.map(cId => ({ series_id: series.id, country_id: cId }));
    if (countryLinks.length > 0) {
      await supabaseRequest('POST', 'series_countries', countryLinks);
    }

    // Link networks
    const networkIds = [];
    for (const n of networksList) {
      const nId = await getOrCreateNetwork(n.name, n.logoPath);
      if (nId) networkIds.push(nId);
    }
    const networkLinks = networkIds.map(nId => ({ series_id: series.id, network_id: nId }));
    if (networkLinks.length > 0) {
      await supabaseRequest('POST', 'series_networks', networkLinks);
    }

    // Link genres
    const genreLinks = [];
    for (const g of detail.genres ?? []) {
      const gId = await getOrCreateGenre(g.name);
      if (gId) {
        genreLinks.push({ series_id: series.id, genre_id: gId });
      }
    }
    if (genreLinks.length > 0) {
      await supabaseRequest('POST', 'series_genres', genreLinks);
    }

    // Scrape episodes & track maxSeasonWithEpisodes
    let maxSeasonWithEpisodes = 0;
    if (detail.seasons && detail.seasons.length > 0) {
      console.log(`   -> Mengambil episode untuk ${detail.seasons.length} season...`);
      for (const season of detail.seasons) {
        if (season.seasonNumber <= 0) continue; // Skip specials
        const eps = await fetchEpisodes(series.slug, season.seasonNumber);
        console.log(`      * Season ${season.seasonNumber}: ${eps.length} episode ditemukan.`);

        if (eps.length > 0) {
          maxSeasonWithEpisodes = Math.max(maxSeasonWithEpisodes, season.seasonNumber);
          const episodesPayload = eps.map(ep => ({
            id: ep.id,
            series_id: series.id,
            season_number: season.seasonNumber,
            episode_number: ep.episodeNumber,
            title: ep.name ?? null,
            overview: ep.overview ?? null,
            still_path: ep.stillPath ?? null,
            runtime: ep.runtime ?? null,
            air_date: ep.airDate ?? null
          }));
          await supabaseRequest('POST', 'episodes', episodesPayload);
        }
        await sleep(300);
      }
    }

    // Update metadata & number_of_seasons
    const updatedSeasons = maxSeasonWithEpisodes > 0 ? maxSeasonWithEpisodes : (detail.seasons?.length ?? series.number_of_seasons);
    await supabaseRequest('PATCH', `series?id=eq.${series.id}`, {
      tmdb_id: tmdbId,
      status: status,
      overview: overview,
      number_of_seasons: updatedSeasons,
      updated_at: new Date().toISOString() // pastikan updated_at terbarui agar berputar
    });

    console.log(`   ✅ Selesai memperbarui series ${series.slug}`);
    successCount++;
    await sleep(500);
  }

  console.log(`\n🎉 Proses sinkronisasi selesai. Berhasil memperbarui ${successCount}/${seriesList.length} series.`);
}

main().catch(console.error);
