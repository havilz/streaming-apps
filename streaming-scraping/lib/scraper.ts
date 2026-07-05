import { gotScraping } from "got-scraping";

const BASE_URL = process.env.IDLIX_BASE_URL || "https://z2.idlixku.com";

interface GateResponse {
  kind: "gate";
  gateToken: string;
  serverNow: number;
  unlockAt: number;
  viewerTier: string;
  maxHeight: number;
  preroll?: unknown;
}

export interface PlayInfoResponse {
  url: string;
  subtitles?: { lang: string; label: string; path: string }[];
  videoId?: string;
  title?: string;
  expiresAt?: number;
}

export interface HomepageMovie {
  id: string;
  contentType: string;
  content: {
    id: string;
    tmdbId?: number;
    imdbId?: string;
    title: string;
    slug: string;
    originalTitle?: string;
    overview?: string;
    tagline?: string;
    posterPath?: string;
    backdropPath?: string;
    logoPath?: string;
    releaseDate?: string;
    runtime?: number;
    voteAverage?: number;
    genres?: { id: number; name: string }[];
    quality?: string;
  };
}

interface HomepageSection {
  id: string;
  type: string;
  title: string;
  slug: string;
  data: HomepageMovie[];
}

interface HomepageResponse {
  above?: HomepageSection[];
  below?: HomepageSection[];
  [key: string]: unknown;
}

/**
 * Creates a persistent set of headers to reuse across requests
 * so the target server sees a consistent browser fingerprint.
 */
function createBrowserHeaders() {
  return {
    "User-Agent":
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
    Accept: "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9,id;q=0.8",
    Referer: `${BASE_URL}/`,
    Origin: BASE_URL,
  };
}

/**
 * Item shape returned from /api/movies and /api/series (flat, no nested content wrapper)
 */
export interface CatalogItem {
  id: string;
  title: string;
  slug: string;
  posterPath?: string;
  backdropPath?: string;
  releaseDate?: string;
  firstAirDate?: string;
  voteAverage?: string | number;
  viewCount?: number;
  quality?: string;
  runtime?: number;
  numberOfSeasons?: number;
  numberOfEpisodes?: number;
  contentType?: string;
  genres?: { id: string; name: string; slug: string }[];
  hasVideo?: boolean;
  country?: string;
}

interface PaginatedResponse {
  data: CatalogItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

/**
 * Fetch one page of movies from /api/movies
 */
export async function fetchMoviesPage(page: number): Promise<PaginatedResponse> {
  const headers = createBrowserHeaders();
  const res = await gotScraping({
    url: `${BASE_URL}/api/movies?page=${page}&limit=24`,
    headers,
    useHeaderGenerator: false,
  });
  if (res.statusCode !== 200) {
    throw new Error(`fetchMoviesPage(${page}) failed: ${res.statusCode}`);
  }
  return JSON.parse(res.body) as PaginatedResponse;
}

/**
 * Fetch one page of series from /api/series
 */
export async function fetchSeriesPage(page: number): Promise<PaginatedResponse> {
  const headers = createBrowserHeaders();
  const res = await gotScraping({
    url: `${BASE_URL}/api/series?page=${page}&limit=24`,
    headers,
    useHeaderGenerator: false,
  });
  if (res.statusCode !== 200) {
    throw new Error(`fetchSeriesPage(${page}) failed: ${res.statusCode}`);
  }
  return JSON.parse(res.body) as PaginatedResponse;
}

/**
 * Fetches the homepage data listing all featured/latest movies and series.
 */
export async function fetchHomepage(): Promise<HomepageMovie[]> {
  const headers = createBrowserHeaders();

  const response = await gotScraping({
    url: `${BASE_URL}/api/homepage`,
    headers,
    useHeaderGenerator: false,
  });

  const data: HomepageResponse = JSON.parse(response.body);
  const allMovies: HomepageMovie[] = [];
  const seenIds = new Set<string>();

  // Collect movies from all sections (above & below)
  const sections = [...(data.above || []), ...(data.below || [])];
  for (const section of sections) {
    if (section.data) {
      for (const item of section.data) {
        const contentId = item.content?.id;
        if (contentId && !seenIds.has(contentId)) {
          seenIds.add(contentId);
          allMovies.push(item);
        }
      }
    }
  }

  return allMovies;
}


/**
 * Fetches the episode details for a given series slug and season/episode.
 */
export async function fetchSeriesEpisodes(
  slug: string,
  seasonNo: number = 1
): Promise<{
  id: string;
  seasonNumber: number;
  episodeNumber: number;
  title?: string;
  overview?: string;
  still_path?: string;
  runtime?: number;
  air_date?: string;
}[]> {
  const headers = createBrowserHeaders();

  const parseEpisodes = (eps: any[], currentSeasonNo: number) => {
    return eps.map(
      (ep: {
        id: string;
        episodeNumber: number;
        name?: string;
        overview?: string;
        stillPath?: string;
        runtime?: number;
        airDate?: string;
      }) => ({
        id: ep.id,
        seasonNumber: currentSeasonNo,
        episodeNumber: ep.episodeNumber,
        title: ep.name,
        overview: ep.overview,
        still_path: ep.stillPath,
        runtime: ep.runtime,
        air_date: ep.airDate,
      })
    );
  };

  // Try dynamic Season [seasonNo] first
  try {
    const response = await gotScraping({
      url: `${BASE_URL}/api/series/${slug}/season/${seasonNo}`,
      headers,
      useHeaderGenerator: false,
    });

    const data = JSON.parse(response.body);
    const episodes = data.season?.episodes;
    if (episodes && Array.isArray(episodes) && episodes.length > 0) {
      return parseEpisodes(episodes, seasonNo);
    }
  } catch {
    // Ignore error and fall back to series metadata lookup
  }

  // Fallback: Fetch series metadata to detect available seasons
  console.log(`[scraper] Season ${seasonNo} failed or empty for ${slug}. Checking seasons metadata...`);
  try {
    const seriesRes = await gotScraping({
      url: `${BASE_URL}/api/series/${slug}`,
      headers,
      useHeaderGenerator: false,
    });
    const seriesData = JSON.parse(seriesRes.body);
    
    // Find first season number
    const seasons = seriesData.seasons;
    if (seasons && Array.isArray(seasons) && seasons.length > 0) {
      const activeSeason = seasons[0];
      const fallbackSeasonNo = activeSeason.seasonNumber ?? 1;
      
      console.log(`[scraper] Fetching episodes for detected season ${fallbackSeasonNo} of ${slug}...`);
      const seasonRes = await gotScraping({
        url: `${BASE_URL}/api/series/${slug}/season/${fallbackSeasonNo}`,
        headers,
        useHeaderGenerator: false,
      });
      const seasonData = JSON.parse(seasonRes.body);
      const episodes = seasonData.season?.episodes;
      if (episodes && Array.isArray(episodes)) {
        return parseEpisodes(episodes, fallbackSeasonNo);
      }
    }
  } catch (err: any) {
    console.error(`[scraper] Robust dynamic episodes fetch failed for ${slug}:`, err.message);
  }

  return [];
}

/**
 * Fetches the seasons and networks details for a given series slug.
 */
export async function fetchSeriesDetails(
  slug: string
): Promise<{
  seasons: { id: string; seasonNumber: number; name: string; episodeCount?: number }[];
  networks: { id: string; name: string; logoPath?: string }[];
} | null> {
  const headers = createBrowserHeaders();
  try {
    const response = await gotScraping({
      url: `${BASE_URL}/api/series/${slug}`,
      headers,
      useHeaderGenerator: false,
    });
    const data = JSON.parse(response.body);
    return {
      seasons: (data.seasons || []).map((s: any) => ({
        id: s.id,
        seasonNumber: s.seasonNumber,
        name: s.name || `Season ${s.seasonNumber}`,
        episodeCount: s.episodeCount,
      })),
      networks: (data.networks || []).map((n: any) => ({
        id: n.id,
        name: n.name,
        logoPath: n.logoPath,
      })),
    };
  } catch (err: any) {
    console.error(`[scraper] Failed to fetch series details for ${slug}:`, err.message);
  }
  return null;
}


/**
 * Attempts to unlock the video URL for a given episode ID
 * by performing the 3-step Pentos flow:
 *  1. Request play-info (GET) -> get gateToken, serverNow, unlockAt + cookies
 *  2. Wait for countdown to expire
 *  3. POST to /api/watch/session/claim with the gateToken & Cookie session -> get claim & redeemUrl
 *  4. POST to redeemUrl with Content-Type: text/plain and the claim token -> get final stream URL
 *
 * Returns the final streaming details or null on failure.
 */
export async function fetchPlayInfo(
  episodeId: string,
  slug: string,
  isMovie: boolean = false
): Promise<PlayInfoResponse | null> {
  const headers = createBrowserHeaders();
  let activeEpisodeId = episodeId;

  if (!isMovie && episodeId.startsWith("tmdb-")) {
    const match = episodeId.match(/s(\d+)e(\d+)$/);
    if (match) {
      const seasonNumber = match[1];
      const episodeNumber = parseInt(match[2]);
      console.log(`[scraper] TMDB fallback episode ID detected: ${episodeId}. Resolving IDLIX ID for season ${seasonNumber}, episode ${episodeNumber}...`);
      try {
        const episodesRes = await gotScraping({
          url: `${BASE_URL}/api/series/${slug}/season/${seasonNumber}`,
          headers: createBrowserHeaders(),
          useHeaderGenerator: false,
        });
        if (episodesRes.statusCode === 200) {
          const episodesData = JSON.parse(episodesRes.body);
          const episodesList = episodesData.season?.episodes || [];
          const matchedEpisode = episodesList.find((ep: any) => ep.episodeNumber === episodeNumber);
          if (matchedEpisode && matchedEpisode.id) {
            console.log(`[scraper] Successfully resolved IDLIX episode ID: ${matchedEpisode.id}`);
            activeEpisodeId = matchedEpisode.id;
          } else {
            console.error(`[scraper] Episode ${episodeNumber} not found on IDLIX for ${slug} S${seasonNumber}`);
            return null;
          }
        } else {
          console.error(`[scraper] Failed to fetch IDLIX episodes for ${slug} S${seasonNumber}: Status ${episodesRes.statusCode}`);
          return null;
        }
      } catch (err: any) {
        console.error(`[scraper] Error resolving IDLIX episode ID:`, err.message);
        return null;
      }
    }
  }

  // Construct a realistic referer URL
  const refererUrl = isMovie
    ? `${BASE_URL}/movie/${slug}`
    : `${BASE_URL}/series/${slug}/season/1/episode/1`;

  const playInfoUrl = isMovie
    ? `${BASE_URL}/api/watch/play-info/movie/${activeEpisodeId}`
    : `${BASE_URL}/api/watch/play-info/episode/${activeEpisodeId}`;

  try {
    // Step 1: Request gate token
    console.log(`[scraper] Step 1: Requesting gate token for ${activeEpisodeId}...`);
    const res1 = await gotScraping({
      url: playInfoUrl,
      headers: {
        ...headers,
        Referer: refererUrl,
      },
      useHeaderGenerator: false,
    });

    if (res1.statusCode !== 200) {
      console.error(`[scraper] Step 1 failed with status ${res1.statusCode}`);
      return null;
    }

    const data: GateResponse | PlayInfoResponse = JSON.parse(res1.body);

    // If it's already unlocked (i.e. doesn't have kind: "gate" in response)
    if ("url" in data) {
      console.log(`[scraper] Already unlocked.`);
      return data as PlayInfoResponse;
    }

    const gateData = data as GateResponse;
    if (!gateData.gateToken) {
      console.error("[scraper] No gateToken in response");
      return null;
    }

    // Extract cookies to send back
    const setCookie = res1.headers['set-cookie'];
    let cookieString = "";
    if (setCookie && Array.isArray(setCookie)) {
      const cookiesMap: Record<string, string> = {};
      for (const cookie of setCookie) {
        const parts = cookie.split(';')[0].split('=');
        if (parts.length >= 2) {
          cookiesMap[parts[0].trim()] = parts[1].trim();
        }
      }
      cookieString = Object.entries(cookiesMap).map(([k, v]) => `${k}=${v}`).join('; ');
    }

    // Step 2: Wait for countdown
    const waitMs = gateData.unlockAt - gateData.serverNow + 1500;
    console.log(`[scraper] Waiting ${(waitMs / 1000).toFixed(1)}s for unlock...`);
    await new Promise((resolve) => setTimeout(resolve, waitMs));

    // Step 3: POST to session claim
    console.log(`[scraper] Step 2: Claiming session for ${activeEpisodeId}...`);
    const claimUrl = `${BASE_URL}/api/watch/session/claim`;
    const res2 = await gotScraping({
      url: claimUrl,
      method: "POST",
      headers: {
        ...headers,
        "content-type": "application/json",
        Cookie: cookieString,
        Referer: refererUrl,
      },
      body: JSON.stringify({ gateToken: gateData.gateToken }),
      useHeaderGenerator: false,
    });

    if (res2.statusCode !== 200) {
      console.error(`[scraper] Claim failed with status ${res2.statusCode}`);
      return null;
    }

    const claimResult = JSON.parse(res2.body);
    if (claimResult.kind !== "pentos" || !claimResult.claim || !claimResult.redeemUrl) {
      console.error(`[scraper] Claim returned invalid state:`, claimResult);
      return null;
    }

    // Step 4: Redeem claim for stream URL
    console.log(`[scraper] Step 3: Redeeming claim token...`);
    const redeemRes = await gotScraping({
      url: claimResult.redeemUrl,
      method: "POST",
      headers: {
        "Content-Type": "text/plain",
        "User-Agent": headers["User-Agent"]
      },
      body: JSON.stringify({ claim: claimResult.claim }),
      useHeaderGenerator: false,
    });

    if (redeemRes.statusCode !== 200) {
      console.error(`[scraper] Redeem failed with status ${redeemRes.statusCode}`);
      return null;
    }

    const finalResult = JSON.parse(redeemRes.body);
    if (!finalResult || typeof finalResult.url !== "string") {
      console.error(`[scraper] Redeem response malformed:`, finalResult);
      return null;
    }

    console.log(`[scraper] Successfully unlocked streaming HLS URL!`);
    return {
      url: finalResult.url,
      subtitles: finalResult.subtitles || [],
      videoId: finalResult.videoId,
      title: claimResult.title,
      expiresAt: finalResult.expiresAt,
    };
  } catch (error) {
    console.error("[scraper] Error in fetchPlayInfo:", error);
    return null;
  }
}
