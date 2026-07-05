/**
 * Edge Function: unlock-stream
 * Melakukan 3-step Pentos flow ke idlix untuk mendapatkan URL stream .m3u8
 * Dipanggil dari Flutter app agar tidak kena Cloudflare 403 di Android
 *
 * Method: POST
 * Body: { episodeId: string, slug: string, isMovie: boolean }
 * Response: { url: string, subtitles: [...] } | { error: string }
 */

// deno-lint-ignore-file no-explicit-any

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const BASE_URL = Deno.env.get('IDLIX_BASE_URL') ?? 'https://z2.idlixku.com';

const BROWSER_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
  'Accept': 'application/json, text/plain, */*',
  'Accept-Language': 'en-US,en;q=0.9,id;q=0.8',
  'Origin': BASE_URL,
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function sleep(ms: number) {
  return new Promise(r => setTimeout(r, ms));
}

function extractCookies(headers: Headers): string {
  const setCookies = headers.getSetCookie();
  if (setCookies.length === 0) {
    const raw = headers.get('set-cookie');
    if (!raw) return '';
    return raw.split(';')[0].trim();
  }

  const cookiesMap: Record<string, string> = {};
  for (const cookie of setCookies) {
    const parts = cookie.split(';')[0].split('=');
    if (parts.length >= 2) {
      cookiesMap[parts[0].trim()] = parts[1].trim();
    }
  }
  return Object.entries(cookiesMap)
    .map(([k, v]) => `${k}=${v}`)
    .join('; ');
}

async function unlockStream(episodeId: string, slug: string, isMovie: boolean) {
  let activeEpisodeId = episodeId;

  if (!isMovie && episodeId.startsWith("tmdb-")) {
    const match = episodeId.match(/s(\d+)e(\d+)$/);
    if (match) {
      const seasonNumber = match[1];
      const episodeNumber = parseInt(match[2]);
      console.log(`[unlock-stream] TMDB fallback episode ID detected: ${episodeId}. Resolving IDLIX ID for season ${seasonNumber}, episode ${episodeNumber}...`);
      try {
        const url = `${BASE_URL}/api/series/${slug}/season/${seasonNumber}`;
        const episodesRes = await fetch(url, {
          headers: BROWSER_HEADERS,
        });
        if (episodesRes.ok) {
          const episodesData = await episodesRes.json();
          const episodesList = episodesData.season?.episodes || [];
          const matchedEpisode = episodesList.find((ep: any) => ep.episodeNumber === episodeNumber);
          if (matchedEpisode && matchedEpisode.id) {
            console.log(`[unlock-stream] Successfully resolved IDLIX episode ID: ${matchedEpisode.id}`);
            activeEpisodeId = matchedEpisode.id;
          } else {
            throw new Error(`Episode ${episodeNumber} not found on IDLIX for ${slug} S${seasonNumber}`);
          }
        } else {
          throw new Error(`Failed to fetch IDLIX episodes for ${slug} S${seasonNumber}: Status ${episodesRes.status}`);
        }
      } catch (err: any) {
        throw new Error(`Error resolving IDLIX episode ID: ${err.message}`);
      }
    }
  }

  const referer = isMovie
    ? `${BASE_URL}/movie/${slug}`
    : `${BASE_URL}/series/${slug}/season/1/episode/1`;

  const playInfoUrl = isMovie
    ? `${BASE_URL}/api/watch/play-info/movie/${activeEpisodeId}`
    : `${BASE_URL}/api/watch/play-info/episode/${activeEpisodeId}`;

  // Step 1: Gate token
  const res1 = await fetch(playInfoUrl, {
    headers: { ...BROWSER_HEADERS, 'Referer': referer },
  });

  if (!res1.ok) {
    throw new Error(`Step 1 failed: ${res1.status}`);
  }

  const body1 = await res1.json();

  // Sudah unlocked
  if (body1.url) return body1;

  const { gateToken, serverNow, unlockAt } = body1;
  if (!gateToken || !serverNow || !unlockAt) {
    throw new Error('Invalid gate response');
  }

  // Ambil cookie
  const cookie = extractCookies(res1.headers);

  // Step 2: Tunggu countdown + 1.5s buffer
  const waitMs = Math.min(Math.max(unlockAt - serverNow + 1500, 0), 20000);
  await sleep(waitMs);

  // Step 3: Claim session
  const res2 = await fetch(`${BASE_URL}/api/watch/session/claim`, {
    method: 'POST',
    headers: {
      ...BROWSER_HEADERS,
      'Referer': referer,
      'Content-Type': 'application/json',
      ...(cookie ? { 'Cookie': cookie } : {}),
    },
    body: JSON.stringify({ gateToken }),
  });

  if (!res2.ok) throw new Error(`Step 2 failed: ${res2.status}`);

  const body2 = await res2.json();
  const { claim, redeemUrl } = body2;
  if (!claim || !redeemUrl) throw new Error('Invalid claim response');

  // Step 4: Redeem
  const res3 = await fetch(redeemUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'text/plain',
      'User-Agent': BROWSER_HEADERS['User-Agent'],
    },
    body: JSON.stringify({ claim }),
  });

  if (!res3.ok) throw new Error(`Step 3 failed: ${res3.status}`);

  const body3 = await res3.json();
  if (!body3.url) throw new Error('No URL in redeem response');

  return {
    url: body3.url,
    subtitles: body3.subtitles ?? [],
    videoId: body3.videoId,
  };
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { episodeId, slug, isMovie } = await req.json();

    if (!episodeId || !slug) {
      return new Response(
        JSON.stringify({ error: 'episodeId and slug are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const result = await unlockStream(episodeId, slug, isMovie ?? false);

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
