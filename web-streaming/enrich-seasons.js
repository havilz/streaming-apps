/**
 * enrich-seasons.js
 * Memproses semua series hasil migrasi di Supabase yang data season/episode/metadata-nya masih kosong.
 * Berjalan secara lokal (tidak ada batas waktu 150 detik) dan melakukan push data ter-normalisasi ke Supabase.
 *
 * Jalankan: node enrich-seasons.js
 */

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

if (!SUPABASE_URL || !SUPABASE_KEY || !TMDB_TOKEN) {
  console.error('❌ Harap pastikan SUPABASE_URL, SUPABASE_SERVICE_KEY, dan TMDB_READ_TOKEN ada di .env');
  process.exit(1);
}

const idlixHeaders = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
  Accept: 'application/json, text/plain, */*',
  Referer: `${BASE_URL}/`,
  Origin: BASE_URL,
};

const COUNTRY_MAP = {
  'US': 'United States',
  'KR': 'South Korea',
  'JP': 'Japan',
  'CN': 'China',
  'ID': 'Indonesia',
  'GB': 'United Kingdom',
  'FR': 'France',
  'DE': 'Germany',
  'IT': 'Italy',
  'ES': 'Spain',
  'CA': 'Canada',
  'AU': 'Australia',
  'IN': 'India',
  'TH': 'Thailand',
  'PH': 'Philippines',
  'MY': 'Malaysia',
  'TW': 'Taiwan',
  'HK': 'Hong Kong',
  'SG': 'Singapore',
  'VN': 'Vietnam',
};

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

// --- REST Client untuk Supabase ---
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

// --- Scraper IDLIX ---
async function fetchSeriesDetail(slug) {
  try {
    const res = await gotScraping({
      url: `${BASE_URL}/api/series/${slug}`,
      headers: idlixHeaders,
      useHeaderGenerator: false,
    });
    if (res.statusCode !== 200) return null;
    return JSON.parse(res.body);
  } catch (err) {
    console.error(`\n❌ Gagal fetch detail IDLIX untuk series: ${slug} (${err.message})`);
    return null;
  }
}

async function fetchEpisodes(slug, seasonNo) {
  try {
    const res = await gotScraping({
      url: `${BASE_URL}/api/series/${slug}/season/${seasonNo}`,
      headers: idlixHeaders,
      useHeaderGenerator: false,
    });
    if (res.statusCode !== 200) return [];
    const data = JSON.parse(res.body);
    return data.season?.episodes ?? [];
  } catch (err) {
    console.error(`\n❌ Gagal fetch episode IDLIX untuk ${slug} S${seasonNo} (${err.message})`);
    return [];
  }
}

// --- TMDB API ---
async function fetchTmdbDetail(tmdbId) {
  if (!tmdbId) return null;
  try {
    const res = await fetch(`https://api.themoviedb.org/3/tv/${tmdbId}`, {
      headers: {
        'Authorization': `Bearer ${TMDB_TOKEN}`,
        'Accept': 'application/json',
      },
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

// --- References Helper ---
const genreCache = new Map();
const countryCache = new Map();
const networkCache = new Map();

async function getOrCreateGenre(name) {
  if (genreCache.has(name)) return genreCache.get(name);
  await supabaseRequest('POST', 'genres?on_conflict=name', { name });
  const data = await supabaseRequest('GET', `genres?name=eq.${encodeURIComponent(name)}&select=id`);
  const id = data?.[0]?.id ?? null;
  if (id) genreCache.set(name, id);
  return id;
}

async function getOrCreateCountry(code, name) {
  const key = `${code}:${name}`;
  if (countryCache.has(key)) return countryCache.get(key);
  await supabaseRequest('POST', 'countries?on_conflict=name', { code, name });
  const data = await supabaseRequest('GET', `countries?name=eq.${encodeURIComponent(name)}&select=id`);
  const id = data?.[0]?.id ?? null;
  if (id) countryCache.set(key, id);
  return id;
}

async function getOrCreateNetwork(name, logoPath) {
  if (networkCache.has(name)) return networkCache.get(name);
  await supabaseRequest('POST', 'networks?on_conflict=name', { name, logo_path: logoPath });
  const data = await supabaseRequest('GET', `networks?name=eq.${encodeURIComponent(name)}&select=id`);
  const id = data?.[0]?.id ?? null;
  if (id) networkCache.set(name, id);
  return id;
}

// ============================================================
// MAIN FUNCTION
// ============================================================
async function main() {
  console.log('🚀 Memulai pengayaan (enrichment) series kosong di Supabase...');

  // Ambil list series dari Supabase menggunakan kueri paginasi paralel untuk mengantisipasi limit 1000 baris
  console.log('   -> Mengunduh daftar series dari Supabase...');
  const pages = await Promise.all([
    supabaseRequest('GET', 'series?select=id,slug,tmdb_id,number_of_seasons,status,episodes(count)&limit=1000&offset=0'),
    supabaseRequest('GET', 'series?select=id,slug,tmdb_id,number_of_seasons,status,episodes(count)&limit=1000&offset=1000'),
    supabaseRequest('GET', 'series?select=id,slug,tmdb_id,number_of_seasons,status,episodes(count)&limit=1000&offset=2000'),
    supabaseRequest('GET', 'series?select=id,slug,tmdb_id,number_of_seasons,status,episodes(count)&limit=1000&offset=3000'),
    supabaseRequest('GET', 'series?select=id,slug,tmdb_id,number_of_seasons,status,episodes(count)&limit=1000&offset=4000'),
    supabaseRequest('GET', 'series?select=id,slug,tmdb_id,number_of_seasons,status,episodes(count)&limit=1000&offset=5000'),
  ]);

  const allSeries = pages.flat().filter(Boolean);

  // Filter series yang data seasons/status-nya null, ATAU yang jumlah episodenya masih 0
  const seriesToEnrich = allSeries.filter(s => {
    const isMetadataMissing = s.number_of_seasons == null || s.status == null;
    const isEpisodesMissing = (s.episodes?.[0]?.count ?? 0) === 0;
    return isMetadataMissing || isEpisodesMissing;
  });

  console.log(`🔍 Ditemukan ${seriesToEnrich.length} series yang memerlukan pengayaan metadata/episode.`);
  if (seriesToEnrich.length === 0) {
    console.log('✅ Semua series sudah lengkap.');
    return;
  }

  let success = 0;
  let failed = 0;

  for (let i = 0; i < seriesToEnrich.length; i++) {
    const series = seriesToEnrich[i];
    console.log(`\n[${i + 1}/${seriesToEnrich.length}] Memproses series: ${series.slug}...`);

    try {
      // 1. Fetch detail dari IDLIX
      const detail = await fetchSeriesDetail(series.slug);
      if (!detail) {
        console.log(`   ⚠️ Detail IDLIX tidak ditemukan, dilewati.`);
        failed++;
        await sleep(300);
        continue;
      }

      const tmdbId = detail.tmdbId ?? series.tmdb_id ?? null;
      let overview = detail.overview ?? null;
      let status = detail.status ?? null;
      let countriesList = [];
      let networksList = [];

      // 2. Enrich via TMDB
      if (tmdbId) {
        const tmdbDetail = await fetchTmdbDetail(tmdbId);
        if (tmdbDetail) {
          overview = tmdbDetail.overview || overview;
          status = tmdbDetail.status || status;
          if (tmdbDetail.production_countries) {
            countriesList = tmdbDetail.production_countries.map(c => ({
              code: c.iso_3166_1,
              name: c.name,
            }));
          }
          if (tmdbDetail.networks) {
            networksList = tmdbDetail.networks.map(n => ({
              name: n.name,
              logoPath: n.logo_path || null,
            }));
          }
        }
      }

      // Fallback country
      if (countriesList.length === 0) {
        const countryCode = detail.country ?? null;
        if (countryCode) {
          const countryName = COUNTRY_MAP[countryCode.toUpperCase()] ?? countryCode;
          countriesList.push({ code: countryCode, name: countryName });
        }
      }

      // Fallback networks
      if (networksList.length === 0 && detail.networks) {
        networksList = detail.networks.map(n => ({
          name: n.name,
          logoPath: n.logoPath ?? n.logo_path ?? null,
        }));
      }

      // 3. Simpan references ke database
      const countryIds = [];
      for (const c of countriesList) {
        const cId = await getOrCreateCountry(c.code, c.name);
        if (cId) countryIds.push(cId);
      }

      const networkIds = [];
      for (const n of networksList) {
        const nId = await getOrCreateNetwork(n.name, n.logoPath);
        if (nId) networkIds.push(nId);
      }

      // 4. Update data series utama
      const totalSeasons = detail.seasons?.length ?? null;
      await supabaseRequest('PATCH', `series?id=eq.${series.id}`, {
        tmdb_id: tmdbId,
        status: status,
        overview: overview,
        number_of_seasons: totalSeasons,
      });

      // Link countries
      for (const cId of countryIds) {
        await supabaseRequest('POST', 'series_countries?on_conflict=series_id,country_id', {
          series_id: series.id,
          country_id: cId,
        });
      }

      // Link networks
      for (const nId of networkIds) {
        await supabaseRequest('POST', 'series_networks?on_conflict=series_id,network_id', {
          series_id: series.id,
          network_id: nId,
        });
      }

      // Link genres
      const genres = detail.genres ?? [];
      for (const g of genres) {
        const genreId = await getOrCreateGenre(g.name);
        if (genreId) {
          await supabaseRequest('POST', 'series_genres?on_conflict=series_id,genre_id', {
            series_id: series.id,
            genre_id: genreId,
          });
        }
      }

      // 5. Scrape dan simpan semua episode untuk setiap season
      if (detail.seasons && detail.seasons.length > 0) {
        console.log(`   -> Mengambil episode untuk ${detail.seasons.length} season...`);
        for (const season of detail.seasons) {
          const eps = await fetchEpisodes(series.slug, season.seasonNumber);
          console.log(`      * Season ${season.seasonNumber}: ${eps.length} episode ditemukan.`);

          for (const ep of eps) {
            await supabaseRequest('POST', 'episodes?on_conflict=id', {
              id: ep.id,
              series_id: series.id,
              season_number: season.seasonNumber,
              episode_number: ep.episodeNumber,
              title: ep.name ?? null,
              overview: ep.overview ?? null,
              still_path: ep.stillPath ?? null,
              runtime: ep.runtime ?? null,
              air_date: ep.airDate ?? null,
            });
          }
          await sleep(200);
        }
      }

      success++;
      console.log(`   ✅ Selesai memperbarui series ${series.slug}`);
    } catch (err) {
      failed++;
      console.error(`   ❌ Error memproses ${series.slug}: ${err.message}`);
    }

    await sleep(400);
  }

  console.log(`\n🎉 Proses Selesai! Berhasil: ${success}, Gagal: ${failed}`);
}

main().catch(err => {
  console.error('\n❌ Terjadi fatal error:', err);
  process.exit(1);
});
