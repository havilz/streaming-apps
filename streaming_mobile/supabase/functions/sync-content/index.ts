/**
 * Edge Function: sync-content
 * Sinkronisasi konten baru dari idlix ke Supabase + enrichment TMDB
 *
 * Method: POST
 * Body: { mode: 'new' | 'ongoing', secret: string }
 *   - new: sync konten baru dari catalog idlix
 *   - ongoing: update episode untuk series dengan status 'Returning Series' atau data yang belum lengkap
 *
 * Response: { synced: number, message: string }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const BASE_URL = Deno.env.get('IDLIX_BASE_URL') ?? 'https://z2.idlixku.com';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const SYNC_SECRET = Deno.env.get('SYNC_SECRET') ?? '';
const TMDB_READ_TOKEN = Deno.env.get('TMDB_READ_TOKEN') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
  'Accept': 'application/json, text/plain, */*',
  'Accept-Language': 'en-US,en;q=0.9,id;q=0.8',
  'Referer': `${BASE_URL}/`,
  'Origin': BASE_URL,
};

const COUNTRY_MAP: Record<string, string> = {
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
  'RU': 'Russia',
  'TR': 'Turkey',
  'BR': 'Brazil',
  'MX': 'Mexico',
};

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

// ─── Fetch catalog page dari idlix ───────────────────────────

async function fetchPage(type: 'movies' | 'series', page: number) {
  const res = await fetch(`${BASE_URL}/api/${type}?page=${page}&limit=24`, {
    headers: HEADERS,
  });
  if (!res.ok) throw new Error(`fetchPage ${type} p${page}: ${res.status}`);
  return res.json();
}

// ─── Fetch detail movie dari idlix ───────────────────────────

async function fetchMovieDetail(slug: string) {
  const res = await fetch(`${BASE_URL}/api/movies/${slug}`, { headers: HEADERS });
  if (!res.ok) return null;
  return res.json();
}

// ─── Fetch detail series dari idlix ──────────────────────────

async function fetchSeriesDetail(slug: string) {
  const res = await fetch(`${BASE_URL}/api/series/${slug}`, { headers: HEADERS });
  if (!res.ok) return null;
  return res.json();
}

// ─── Fetch episodes untuk satu season ────────────────────────

async function fetchEpisodes(slug: string, seasonNo: number) {
  const res = await fetch(
    `${BASE_URL}/api/series/${slug}/season/${seasonNo}`,
    { headers: HEADERS },
  );
  if (!res.ok) return [];
  const data = await res.json();
  return data.season?.episodes ?? [];
}

// ─── Fetch metadata dari TMDB ────────────────────────────────

async function fetchTmdbDetail(tmdbId: number, isMovie: boolean) {
  if (!TMDB_READ_TOKEN || !tmdbId) return null;
  const path = isMovie ? `movie/${tmdbId}` : `tv/${tmdbId}`;
  try {
    const res = await fetch(`https://api.themoviedb.org/3/${path}`, {
      headers: {
        'Authorization': `Bearer ${TMDB_READ_TOKEN}`,
        'Accept': 'application/json',
      },
    });
    if (!res.ok) return null;
    return res.json();
  } catch (_) {
    return null;
  }
}

// ─── Upsert referensi ────────────────────────────────────────

async function getOrCreateGenre(
  supabase: ReturnType<typeof createClient>,
  name: string,
  cache: Map<string, number>,
): Promise<number | null> {
  if (cache.has(name)) return cache.get(name)!;
  await supabase.from('genres').upsert({ name }, { onConflict: 'name' });
  const { data } = await supabase.from('genres').select('id').eq('name', name).single();
  const id = data?.id ?? null;
  if (id) cache.set(name, id);
  return id;
}

async function getOrCreateCountry(
  supabase: ReturnType<typeof createClient>,
  code: string,
  name: string,
  cache: Map<string, number>,
): Promise<number | null> {
  const key = `${code}:${name}`;
  if (cache.has(key)) return cache.get(key)!;
  await supabase.from('countries').upsert({ code, name }, { onConflict: 'name' });
  const { data } = await supabase.from('countries').select('id').eq('name', name).single();
  const id = data?.id ?? null;
  if (id) cache.set(key, id);
  return id;
}

async function getOrCreateNetwork(
  supabase: ReturnType<typeof createClient>,
  name: string,
  logoPath: string | null,
  cache: Map<string, number>,
): Promise<number | null> {
  if (cache.has(name)) return cache.get(name)!;
  await supabase.from('networks').upsert({ name, logo_path: logoPath }, { onConflict: 'name' });
  const { data } = await supabase.from('networks').select('id').eq('name', name).single();
  const id = data?.id ?? null;
  if (id) cache.set(name, id);
  return id;
}

// ─── Sync konten baru ─────────────────────────────────────────

async function syncNew(supabase: ReturnType<typeof createClient>) {
  let synced = 0;
  const genreCache = new Map<string, number>();
  const countryCache = new Map<string, number>();
  const networkCache = new Map<string, number>();

  for (const type of ['movies', 'series'] as const) {
    const first = await fetchPage(type, 1);
    const totalPages = first.pagination?.totalPages ?? 1;
    let consecutiveExisting = 0;
    let shouldStopType = false;

    for (let page = 1; page <= totalPages; page++) {
      if (shouldStopType) break;
      const pageData = page === 1 ? first : await fetchPage(type, page);
      const items: any[] = pageData.data ?? [];

      for (const item of items) {
        const isMovie = type === 'movies';
        const table = isMovie ? 'movies' : 'series';

        // Cek apakah sudah ada
        const { data: existing } = await supabase
          .from(table)
          .select('id')
          .eq('id', item.id)
          .maybeSingle();

        if (existing) {
          consecutiveExisting++;
          if (consecutiveExisting >= 5) {
            shouldStopType = true;
            break;
          }
          continue;
        }

        consecutiveExisting = 0; // Reset counter if we find a new item

        // Fetch detail lengkap dari idlix
        const detail = isMovie 
          ? await fetchMovieDetail(item.slug)
          : await fetchSeriesDetail(item.slug);
        
        await sleep(300);

        const tmdbId = detail?.tmdbId ?? item.tmdbId ?? null;
        let overview = detail?.overview ?? null;
        let status = detail?.status ?? null;
        let runtime = isMovie ? (detail?.runtime ?? null) : null;
        let countriesList: { code: string; name: string }[] = [];
        let networksList: { name: string; logoPath: string | null }[] = [];

        // Enrich via TMDB
        if (tmdbId) {
          const tmdbDetail = await fetchTmdbDetail(tmdbId, isMovie);
          if (tmdbDetail) {
            overview = tmdbDetail.overview || overview;
            status = tmdbDetail.status || status;
            if (isMovie && tmdbDetail.runtime) {
              runtime = tmdbDetail.runtime;
            }
            if (tmdbDetail.production_countries) {
              countriesList = tmdbDetail.production_countries.map((c: any) => ({
                code: c.iso_3166_1,
                name: c.name,
              }));
            }
            if (!isMovie && tmdbDetail.networks) {
              networksList = tmdbDetail.networks.map((n: any) => ({
                name: n.name,
                logoPath: n.logo_path || null,
              }));
            }
          }
        }

        // Fallback untuk countries
        if (countriesList.length === 0) {
          const countryCode = detail?.country ?? item.country ?? null;
          if (countryCode) {
            const countryName = COUNTRY_MAP[countryCode.toUpperCase()] ?? countryCode;
            countriesList.push({ code: countryCode, name: countryName });
          }
        }

        // Fallback untuk networks
        if (!isMovie && networksList.length === 0 && detail?.networks) {
          networksList = detail.networks.map((n: any) => ({
            name: n.name,
            logoPath: n.logoPath ?? n.logo_path ?? null,
          }));
        }

        // Upsert references
        const countryIds: number[] = [];
        for (const c of countriesList) {
          const cId = await getOrCreateCountry(supabase, c.code, c.name, countryCache);
          if (cId) countryIds.push(cId);
        }

        const networkIds: number[] = [];
        if (!isMovie) {
          for (const n of networksList) {
            const nId = await getOrCreateNetwork(supabase, n.name, n.logoPath, networkCache);
            if (nId) networkIds.push(nId);
          }
        }

        const releaseDate = item.releaseDate ?? item.firstAirDate ?? null;

        if (isMovie) {
          // Insert movie
          await supabase.from('movies').upsert({
            id: item.id,
            tmdb_id: tmdbId,
            imdb_id: detail?.imdbId ?? null,
            title: item.title,
            slug: item.slug,
            original_title: detail?.originalTitle ?? null,
            overview: overview,
            poster_path: item.posterPath ?? null,
            backdrop_path: item.backdropPath ?? null,
            release_date: releaseDate,
            runtime: runtime,
            vote_average: item.voteAverage ? parseFloat(String(item.voteAverage)) : null,
            quality: item.quality ?? null,
            status: status,
          });
        } else {
          // Insert series
          const seasons = detail?.seasons ?? [];
          await supabase.from('series').upsert({
            id: item.id,
            tmdb_id: tmdbId,
            imdb_id: detail?.imdbId ?? null,
            title: item.title,
            slug: item.slug,
            original_title: detail?.originalTitle ?? null,
            overview: overview,
            poster_path: item.posterPath ?? detail?.posterPath ?? null,
            backdrop_path: item.backdropPath ?? detail?.backdropPath ?? null,
            first_air_date: releaseDate,
            vote_average: item.voteAverage ? parseFloat(String(item.voteAverage)) : null,
            quality: item.quality ?? null,
            status: status,
            number_of_seasons: seasons.length > 0 ? seasons.length : null,
          });

          // Insert episodes untuk season pertama
          if (seasons.length > 0) {
            const eps = await fetchEpisodes(item.slug, seasons[0].seasonNumber ?? 1);
            for (const ep of eps) {
              await supabase.from('episodes').upsert({
                id: ep.id,
                series_id: item.id,
                season_number: seasons[0].seasonNumber ?? 1,
                episode_number: ep.episodeNumber,
                title: ep.name ?? null,
                overview: ep.overview ?? null,
                still_path: ep.stillPath ?? null,
                runtime: ep.runtime ?? null,
                air_date: ep.airDate ?? null,
              });
            }
            await sleep(300);
          }
        }

        // Insert country relations
        for (const cId of countryIds) {
          const junctionTable = isMovie ? 'movie_countries' : 'series_countries';
          const idKey = isMovie ? 'movie_id' : 'series_id';
          await supabase
            .from(junctionTable)
            .upsert({ [idKey]: item.id, country_id: cId });
        }

        // Insert network relations
        if (!isMovie) {
          for (const nId of networkIds) {
            await supabase
              .from('series_networks')
              .upsert({ series_id: item.id, network_id: nId });
          }
        }

        // Insert genre relations
        const genres = item.genres ?? detail?.genres ?? [];
        for (const g of genres) {
          const genreId = await getOrCreateGenre(supabase, g.name, genreCache);
          if (genreId) {
            const junctionTable = isMovie ? 'movie_genres' : 'series_genres';
            const idKey = isMovie ? 'movie_id' : 'series_id';
            await supabase
              .from(junctionTable)
              .upsert({ [idKey]: item.id, genre_id: genreId });
          }
        }

        synced++;
        await sleep(200);
      }

      await sleep(300);
    }
  }

  return synced;
}

// ─── Update episode series ongoing ───────────────────────────

async function syncOngoing(supabase: ReturnType<typeof createClient>) {
  let updated = 0;
  const genreCache = new Map<string, number>();
  const countryCache = new Map<string, number>();
  const networkCache = new Map<string, number>();

  // Ambil semua series ongoing atau series yang datanya belum lengkap
  const { data: ongoingSeries } = await supabase
    .from('series')
    .select('id, slug, number_of_seasons, status, tmdb_id')
    .or('status.eq.Returning Series,status.is.null,number_of_seasons.is.null')
    .limit(10);

  for (const series of ongoingSeries ?? []) {
    const detail = await fetchSeriesDetail(series.slug);
    if (!detail) continue;

    const tmdbId = detail.tmdbId ?? series.tmdb_id ?? null;
    let overview = detail.overview ?? null;
    let status = detail.status ?? null;
    let countriesList: { code: string; name: string }[] = [];
    let networksList: { name: string; logoPath: string | null }[] = [];

    // Enrich via TMDB
    if (tmdbId) {
      const tmdbDetail = await fetchTmdbDetail(tmdbId, false);
      if (tmdbDetail) {
        overview = tmdbDetail.overview || overview;
        status = tmdbDetail.status || status;
        if (tmdbDetail.production_countries) {
          countriesList = tmdbDetail.production_countries.map((c: any) => ({
            code: c.iso_3166_1,
            name: c.name,
          }));
        }
        if (tmdbDetail.networks) {
          networksList = tmdbDetail.networks.map((n: any) => ({
            name: n.name,
            logoPath: n.logo_path || null,
          }));
        }
      }
    }

    // Fallback countries
    if (countriesList.length === 0) {
      const countryCode = detail.country ?? null;
      if (countryCode) {
        const countryName = COUNTRY_MAP[countryCode.toUpperCase()] ?? countryCode;
        countriesList.push({ code: countryCode, name: countryName });
      }
    }

    // Fallback networks
    if (networksList.length === 0 && detail.networks) {
      networksList = detail.networks.map((n: any) => ({
        name: n.name,
        logoPath: n.logoPath ?? n.logo_path ?? null,
      }));
    }

    // Upsert references
    const countryIds: number[] = [];
    for (const c of countriesList) {
      const cId = await getOrCreateCountry(supabase, c.code, c.name, countryCache);
      if (cId) countryIds.push(cId);
    }

    const networkIds: number[] = [];
    for (const n of networksList) {
      const nId = await getOrCreateNetwork(supabase, n.name, n.logoPath, networkCache);
      if (nId) networkIds.push(nId);
    }

    // Update series metadata
    await supabase
      .from('series')
      .update({
        tmdb_id: tmdbId,
        status: status,
        overview: overview,
        number_of_seasons: detail.seasons?.length ?? series.number_of_seasons,
      })
      .eq('id', series.id);

    // Link countries
    for (const cId of countryIds) {
      await supabase
        .from('series_countries')
        .upsert({ series_id: series.id, country_id: cId });
    }

    // Link networks
    for (const nId of networkIds) {
      await supabase
        .from('series_networks')
        .upsert({ series_id: series.id, network_id: nId });
    }

    // Link genres
    const genres = detail.genres ?? [];
    for (const g of genres) {
      const genreId = await getOrCreateGenre(supabase, g.name, genreCache);
      if (genreId) {
        await supabase
          .from('series_genres')
          .upsert({ series_id: series.id, genre_id: genreId });
      }
    }

    // Update episodes untuk setiap season
    for (const season of detail.seasons ?? []) {
      const eps = await fetchEpisodes(series.slug, season.seasonNumber);
      for (const ep of eps) {
        await supabase.from('episodes').upsert({
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
      await sleep(300);
    }

    updated++;
    await sleep(400);
  }

  return updated;
}

// ─── Main handler ─────────────────────────────────────────────

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { mode, secret } = await req.json();

    // Validasi secret
    if (SYNC_SECRET && secret !== SYNC_SECRET) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    let synced = 0;
    let message = '';

    if (mode === 'ongoing') {
      synced = await syncOngoing(supabase);
      message = `Updated ${synced} ongoing/incomplete series`;
    } else {
      synced = await syncNew(supabase);
      message = `Synced ${synced} new items`;
    }

    return new Response(
      JSON.stringify({ synced, message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
