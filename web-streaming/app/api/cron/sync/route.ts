import { NextRequest, NextResponse } from "next/server";
import { getDb } from "@/lib/db";
import { fetchHomepage, HomepageMovie, fetchMoviesPage, fetchSeriesPage, CatalogItem, fetchSeriesDetails } from "@/lib/scraper";

export const dynamic = "force-dynamic";

/**
 * Helper: insert a CatalogItem (from /api/movies or /api/series) into SQLite.
 * Returns true if a new row was inserted.
 */
function insertCatalogItem(
  db: ReturnType<typeof getDb>,
  item: CatalogItem,
  contentType: string
): boolean {
  const insertMovie = db.prepare(`
    INSERT INTO movies (
      id, title, slug,
      poster_path, backdrop_path,
      content_type, release_date, runtime, vote_average, genres, quality, country
    ) VALUES (
      @id, @title, @slug,
      @poster_path, @backdrop_path,
      @content_type, @release_date, @runtime, @vote_average, @genres, @quality, @country
    )
    ON CONFLICT(id) DO UPDATE SET
      country = excluded.country,
      release_date = excluded.release_date,
      vote_average = excluded.vote_average
  `);

  const insertEpisode = db.prepare(`
    INSERT OR IGNORE INTO episodes (id, movie_id, season_number, episode_number, title)
    VALUES (@id, @movie_id, @season_number, @episode_number, @title)
  `);

  const releaseDate = item.releaseDate ?? item.firstAirDate ?? null;
  const voteAverage =
    item.voteAverage != null ? parseFloat(String(item.voteAverage)) : null;

  const result = insertMovie.run({
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

  if (result.changes > 0 && contentType === "movie") {
    insertEpisode.run({
      id: item.id,
      movie_id: item.id,
      season_number: 1,
      episode_number: 1,
      title: item.title,
    });
  }

  return result.changes > 0;
}

/**
 * POST /api/cron/sync
 *
 * Modes:
 *  - mode=homepage (default): fetch homepage sections only (~120 items, fast)
 *  - mode=full: paginate through /api/movies + /api/series
 *
 * Params (body JSON or query string):
 *  - mode: "homepage" | "full"  (default: "homepage")
 *  - type: "movies" | "series" | "all"  (default: "all", only for mode=full)
 *  - maxPages: number  (default: 0 = all pages, only for mode=full)
 *  - startPage: number  (default: 1, only for mode=full)
 *
 * Protected by CRON_SECRET header: x-cron-secret
 */
export async function POST(request: NextRequest) {
  // Auth check
  const secret = request.headers.get("x-cron-secret");
  if (secret !== process.env.CRON_SECRET) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  // Parse params
  let body: Record<string, string | number> = {};
  try {
    const text = await request.text();
    if (text) body = JSON.parse(text);
  } catch {
    // ignore invalid JSON body
  }

  const url = new URL(request.url);
  const mode = (body.mode as string) ?? url.searchParams.get("mode") ?? "homepage";
  const type = (body.type as string) ?? url.searchParams.get("type") ?? "all";
  const maxPages = parseInt(String(body.maxPages ?? url.searchParams.get("maxPages") ?? "0"), 10);
  const startPage = parseInt(String(body.startPage ?? url.searchParams.get("startPage") ?? "1"), 10);

  const db = getDb();

  try {
    if (mode === "sync-networks") {
      // ── Batch sync networks for all series that have null/empty networks ──
      const batchSize = parseInt(String(body.batchSize ?? url.searchParams.get("batchSize") ?? "50"), 10);
      const offset = parseInt(String(body.offset ?? url.searchParams.get("offset") ?? "0"), 10);

      const seriesList = db
        .prepare(
          `SELECT id, slug FROM movies
           WHERE content_type = 'series'
             AND (networks IS NULL OR networks = '' OR networks = '[]' OR networks = 'null')
           LIMIT @limit OFFSET @offset`
        )
        .all({ limit: batchSize, offset }) as { id: string; slug: string }[];

      const totalPending = (
        db
          .prepare(
            `SELECT COUNT(*) as c FROM movies
             WHERE content_type = 'series'
               AND (networks IS NULL OR networks = '' OR networks = '[]' OR networks = 'null')`
          )
          .get() as { c: number }
      ).c;

      const updateStmt = db.prepare(
        "UPDATE movies SET networks = ?, seasons = ? WHERE id = ?"
      );

      let updated = 0;
      let failed = 0;

      for (const series of seriesList) {
        try {
          const details = await fetchSeriesDetails(series.slug);
          if (details) {
            updateStmt.run(
              JSON.stringify(details.networks),
              details.seasons.length > 0 ? JSON.stringify(details.seasons) : null,
              series.id
            );
            updated++;
          } else {
            failed++;
          }
          // Small delay to avoid rate limiting
          await new Promise((r) => setTimeout(r, 200));
        } catch {
          failed++;
        }
      }

      return NextResponse.json({
        success: true,
        mode: "sync-networks",
        processed: seriesList.length,
        updated,
        failed,
        remaining: Math.max(0, totalPending - updated),
        totalPending,
        nextOffset: offset + batchSize,
      });
    }

    if (mode === "homepage") {
      // --- Legacy homepage mode ---
      const movies = await fetchHomepage();
      let inserted = 0;
      let skipped = 0;

      const insertMovie = db.prepare(`
        INSERT OR IGNORE INTO movies (
          id, tmdb_id, imdb_id, title, slug, original_title,
          overview, tagline, poster_path, backdrop_path, logo_path,
          content_type, release_date, runtime, vote_average, genres, quality
        ) VALUES (
          @id, @tmdb_id, @imdb_id, @title, @slug, @original_title,
          @overview, @tagline, @poster_path, @backdrop_path, @logo_path,
          @content_type, @release_date, @runtime, @vote_average, @genres, @quality
        )
      `);

      const insertEpisode = db.prepare(`
        INSERT OR IGNORE INTO episodes (id, movie_id, season_number, episode_number, title)
        VALUES (@id, @movie_id, @season_number, @episode_number, @title)
      `);

      const syncTransaction = db.transaction((movieList: HomepageMovie[]) => {
        for (const item of movieList) {
          const c = item.content;
          if (!c || !c.id) continue;
          const result = insertMovie.run({
            id: c.id,
            tmdb_id: c.tmdbId ?? null,
            imdb_id: c.imdbId ?? null,
            title: c.title,
            slug: c.slug,
            original_title: c.originalTitle ?? null,
            overview: c.overview ?? null,
            tagline: c.tagline ?? null,
            poster_path: c.posterPath ?? null,
            backdrop_path: c.backdropPath ?? null,
            logo_path: c.logoPath ?? null,
            content_type: item.contentType,
            release_date: c.releaseDate ?? null,
            runtime: c.runtime ?? null,
            vote_average: c.voteAverage ?? null,
            genres: c.genres ? JSON.stringify(c.genres) : null,
            quality: c.quality ?? null,
          });
          if (result.changes > 0) {
            inserted++;
            if (item.contentType === "movie") {
              insertEpisode.run({ id: c.id, movie_id: c.id, season_number: 1, episode_number: 1, title: c.title });
            }
          } else {
            skipped++;
          }
        }
      });
      syncTransaction(movies);

      return NextResponse.json({ success: true, mode: "homepage", total: movies.length, inserted, skipped });
    }

    // --- Full sync mode (paginated) ---
    let totalInserted = 0;
    let totalSkipped = 0;
    let moviePages = 0;
    let seriesPages = 0;

    const syncPage = db.transaction((items: CatalogItem[], contentType: string) => {
      let ins = 0;
      let skip = 0;
      for (const item of items) {
        if (insertCatalogItem(db, item, contentType)) ins++;
        else skip++;
      }
      return { ins, skip };
    });

    // Sync movies
    if (type === "movies" || type === "all") {
      console.log("[sync] Starting full movies sync...");
      const firstPage = await fetchMoviesPage(startPage);
      const totalMoviePages = maxPages > 0 ? Math.min(maxPages + startPage - 1, firstPage.pagination.totalPages) : firstPage.pagination.totalPages;

      // Process first page
      const r0 = syncPage(firstPage.data, "movie");
      totalInserted += r0.ins;
      totalSkipped += r0.skip;
      moviePages++;

      // Process remaining pages
      for (let page = startPage + 1; page <= totalMoviePages; page++) {
        try {
          const pageData = await fetchMoviesPage(page);
          const r = syncPage(pageData.data, "movie");
          totalInserted += r.ins;
          totalSkipped += r.skip;
          moviePages++;
          // Small delay to avoid rate limiting
          await new Promise((resolve) => setTimeout(resolve, 150));
        } catch (err) {
          console.error(`[sync] Failed to fetch movies page ${page}:`, err);
        }
      }
      console.log(`[sync] Movies done: ${moviePages} pages, ${totalInserted} inserted`);
    }

    // Sync series
    if (type === "series" || type === "all") {
      console.log("[sync] Starting full series sync...");
      const seriesInsertedBefore = totalInserted;
      const firstPage = await fetchSeriesPage(startPage);
      const totalSeriesPages = maxPages > 0 ? Math.min(maxPages + startPage - 1, firstPage.pagination.totalPages) : firstPage.pagination.totalPages;

      const r0 = syncPage(firstPage.data, "series");
      totalInserted += r0.ins;
      totalSkipped += r0.skip;
      seriesPages++;

      for (let page = startPage + 1; page <= totalSeriesPages; page++) {
        try {
          const pageData = await fetchSeriesPage(page);
          const r = syncPage(pageData.data, "series");
          totalInserted += r.ins;
          totalSkipped += r.skip;
          seriesPages++;
          await new Promise((resolve) => setTimeout(resolve, 150));
        } catch (err) {
          console.error(`[sync] Failed to fetch series page ${page}:`, err);
        }
      }
      console.log(`[sync] Series done: ${seriesPages} pages, ${totalInserted - seriesInsertedBefore} inserted`);
    }

    return NextResponse.json({
      success: true,
      mode: "full",
      type,
      moviePages,
      seriesPages,
      totalInserted,
      totalSkipped,
    });
  } catch (error) {
    console.error("[sync] Error:", error);
    return NextResponse.json({ error: "Sync failed", details: String(error) }, { status: 500 });
  }
}

/**
 * GET /api/cron/sync — simple health check
 */
export async function GET() {
  const db = getDb();
  const count = db.prepare("SELECT COUNT(*) as total FROM movies").get() as { total: number };
  const noNetworks = db.prepare(
    "SELECT COUNT(*) as c FROM movies WHERE content_type = 'series' AND (networks IS NULL OR networks = '' OR networks = '[]' OR networks = 'null')"
  ).get() as { c: number };
  return NextResponse.json({
    status: "Sync endpoint ready. Use POST to trigger.",
    totalMoviesInDb: count.total,
    seriesMissingNetworks: noNetworks.c,
    usage: {
      homepage: 'POST with header x-cron-secret + body {"mode":"homepage"}',
      fullSync: 'POST with header x-cron-secret + body {"mode":"full","type":"all"}',
      moviesOnly: 'POST + body {"mode":"full","type":"movies","maxPages":10}',
      resume: 'POST + body {"mode":"full","type":"movies","startPage":50}',
      syncNetworks: 'POST + body {"mode":"sync-networks","batchSize":50,"offset":0}',
    }
  });
}
