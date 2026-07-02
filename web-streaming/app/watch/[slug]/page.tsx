import { notFound } from "next/navigation";
import Link from "next/link";
import { getDb } from "@/lib/db";
import { fetchSeriesEpisodes, fetchSeriesDetails } from "@/lib/scraper";
import Player from "./player";

interface MovieRow {
  id: string;
  title: string;
  slug: string;
  original_title: string | null;
  overview: string | null;
  tagline: string | null;
  poster_path: string | null;
  backdrop_path: string | null;
  logo_path: string | null;
  content_type: string;
  release_date: string | null;
  runtime: number | null;
  vote_average: number | null;
  genres: string | null;
  quality: string | null;
  seasons: string | null;
  networks: string | null;
  country: string | null;
}

interface EpisodeRow {
  id: string;
  movie_id: string;
  season_number: number;
  episode_number: number;
  title: string | null;
  overview: string | null;
  still_path: string | null;
  runtime: number | null;
  air_date: string | null;
  video_url: string | null;
  video_type: string | null;
  video_fetched_at: string | null;
}

interface SeasonMeta {
  id: string;
  seasonNumber: number;
  name: string;
  episodeCount?: number;
}

interface PageProps {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ ep?: string; season?: string }>;
}

export default async function Watch({ params, searchParams }: PageProps) {
  const { slug } = await params;
  const { ep, season: seasonParam } = await searchParams;
  const db = getDb();

  // Fetch the movie/series by slug
  const movie = db.prepare("SELECT * FROM movies WHERE slug = ?").get(slug) as MovieRow | undefined;
  if (!movie) notFound();

  const isMovie = movie.content_type === "movie";

  // ─────────────────────────────────────────────────
  // SEASONS LOGIC (TV Series only)
  // ─────────────────────────────────────────────────
  let seasons: SeasonMeta[] = [];

  if (!isMovie) {
    // Try to load seasons from DB cache first
    if (movie.seasons) {
      try {
        seasons = JSON.parse(movie.seasons);
      } catch {
        seasons = [];
      }
    }

    // If seasons not cached OR networks not cached, fetch from API
    const needsNetworks = !movie.networks || movie.networks === "[]" || movie.networks === "null";
    if (seasons.length === 0 || needsNetworks) {
      const details = await fetchSeriesDetails(slug);
      if (details && details.seasons.length > 0) {
        seasons = details.seasons;
        db.prepare("UPDATE movies SET seasons = ?, networks = ? WHERE id = ?").run(
          JSON.stringify(details.seasons),
          JSON.stringify(details.networks),
          movie.id
        );
      } else if (details && needsNetworks) {
        // Update networks even if seasons unchanged
        db.prepare("UPDATE movies SET networks = ? WHERE id = ?").run(
          JSON.stringify(details.networks),
          movie.id
        );
      }
    }
  }

  // Determine current season number
  const defaultSeasonNo = seasons.length > 0 ? seasons[0].seasonNumber : 1;
  const currentSeasonNo = seasonParam ? parseInt(seasonParam, 10) : defaultSeasonNo;

  // ─────────────────────────────────────────────────
  // EPISODES LOGIC
  // ─────────────────────────────────────────────────
  const insertEpisode = db.prepare(`
    INSERT OR IGNORE INTO episodes (
      id, movie_id, season_number, episode_number, title, overview, still_path, runtime, air_date
    ) VALUES (
      @id, @movie_id, @season_number, @episode_number, @title, @overview, @still_path, @runtime, @air_date
    )
  `);

  const insertEpisodesTx = db.transaction(
    (eps: ReturnType<typeof fetchSeriesEpisodes> extends Promise<infer T> ? T : never) => {
      for (const ep of eps) {
        insertEpisode.run({
          id: ep.id,
          movie_id: movie!.id,
          season_number: ep.seasonNumber,
          episode_number: ep.episodeNumber,
          title: ep.title ?? null,
          overview: ep.overview ?? null,
          still_path: ep.still_path ?? null,
          runtime: ep.runtime ?? null,
          air_date: ep.air_date ?? null,
        });
      }
    }
  );

  // Get episodes for current season from DB
  let episodes = db
    .prepare(
      "SELECT * FROM episodes WHERE movie_id = ? AND season_number = ? ORDER BY episode_number ASC"
    )
    .all(movie.id, currentSeasonNo) as EpisodeRow[];

  // If not cached yet, scrape on the fly
  if (!isMovie && episodes.length === 0) {
    console.log(
      `[watch] Episodes for ${slug} S${currentSeasonNo} not cached. Syncing...`
    );
    const scraped = await fetchSeriesEpisodes(slug, currentSeasonNo);
    if (scraped.length > 0) {
      insertEpisodesTx(scraped);
      episodes = db
        .prepare(
          "SELECT * FROM episodes WHERE movie_id = ? AND season_number = ? ORDER BY episode_number ASC"
        )
        .all(movie.id, currentSeasonNo) as EpisodeRow[];
    }
  }

  // If still no episodes (movie OR series without episodes) – for movie use id directly
  const currentEpNum = ep ? parseInt(ep, 10) : 1;
  const currentEpisode = isMovie
    ? ({ id: movie.id, episode_number: 1 } as EpisodeRow)
    : episodes.find((e) => e.episode_number === currentEpNum) ?? episodes[0];

  const genresList = movie.genres ? JSON.parse(movie.genres) : [];
  const releaseYear = movie.release_date
    ? new Date(movie.release_date).getFullYear()
    : null;

  return (
    <div className="max-w-[1400px] mx-auto px-4 sm:px-6 lg:px-10 py-10 flex flex-col lg:flex-row gap-10">
      {/* Left Column: Player & Metadata */}
      <div className="flex-1 min-w-0 flex flex-col gap-6">
        {/* Player */}
        {currentEpisode ? (
          <Player
            episodeId={currentEpisode.id}
            slug={movie.slug}
            isMovie={isMovie}
            title={isMovie ? movie.title : (currentEpisode as EpisodeRow).title || movie.title}
          />
        ) : (
          <div className="player-container flex flex-col items-center justify-center bg-black/40 border border-white/5 rounded-xl text-center">
            <p className="text-text-muted">Episode tidak ditemukan untuk season ini.</p>
          </div>
        )}

        {/* Episode Info */}
        <div className="flex flex-col gap-3">
          <h1 className="text-2xl sm:text-3xl font-bold font-outfit text-white">
            {isMovie
              ? movie.title
              : !isMovie && currentEpisode && (currentEpisode as EpisodeRow).episode_number
              ? `${movie.title} — S${currentSeasonNo} E${(currentEpisode as EpisodeRow).episode_number}: ${(currentEpisode as EpisodeRow).title || "Episode Baru"}`
              : movie.title}
          </h1>
          <div className="flex flex-wrap items-center gap-3">
            <span className="badge badge-quality">{movie.quality || "HD"}</span>
            <span className="badge badge-type">{isMovie ? "Film" : "Serial TV"}</span>
            {movie.vote_average && (
              <span className="text-amber-400 font-semibold text-sm">
                ★ {Number(movie.vote_average).toFixed(1)}
              </span>
            )}
            {releaseYear && <span className="text-text-muted text-sm">{releaseYear}</span>}
            {movie.runtime && <span className="text-text-muted text-sm">{movie.runtime} mnt</span>}
          </div>

          {/* Overview */}
          <div className="mt-2 border-t border-white/5 pt-4">
            <h2 className="text-lg font-semibold font-outfit text-white mb-2">Sinopsis</h2>
            <p className="text-text-muted text-sm sm:text-base leading-relaxed">
              {(!isMovie && currentEpisode && (currentEpisode as EpisodeRow).overview) ||
                movie.overview ||
                "Sinopsis tidak tersedia."}
            </p>
          </div>

          {/* Genres */}
          {genresList.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-2">
              {genresList.map((g: { id: number; name: string }) => (
                <span
                  key={g.id}
                  className="text-xs bg-bg-elevated border border-white/5 px-3 py-1 rounded-full text-text-muted"
                >
                  {g.name}
                </span>
              ))}
            </div>
          )}

          {/* Season Selector (Horizontal scrollable layout) */}
          {!isMovie && seasons.length > 1 && (
            <div className="flex flex-col gap-3 border-t border-white/5 pt-5 mt-4 w-full max-w-full overflow-hidden">
              <h2 className="font-outfit font-bold text-base text-white">Pilih Season</h2>
              <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-thin snap-x snap-mandatory flex-nowrap w-full">
                {seasons.map((s) => {
                  const isActiveSeason = s.seasonNumber === currentSeasonNo;
                  return (
                    <Link
                      key={s.id}
                      href={`/watch/${movie.slug}?season=${s.seasonNumber}&ep=1`}
                      scroll={false}
                      className={`flex items-center gap-2 px-4 py-2 rounded-full text-sm font-semibold font-outfit border shrink-0 transition-all duration-200 snap-start ${
                        isActiveSeason
                          ? "bg-primary border-primary text-white shadow-lg shadow-primary/25"
                          : "bg-bg-elevated border-white/10 text-text-muted hover:border-white/30 hover:text-white"
                      }`}
                    >
                      <svg className={`w-3.5 h-3.5 ${isActiveSeason ? "text-white" : "text-text-muted"}`} fill="currentColor" viewBox="0 0 20 20">
                        <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"/>
                      </svg>
                      {s.name}
                      {s.episodeCount && (
                        <span className={`text-[10px] px-1.5 py-0.5 rounded-full ${
                          isActiveSeason ? "bg-white/20 text-white" : "bg-white/5 text-text-muted"
                        }`}>
                          {s.episodeCount}
                        </span>
                      )}
                    </Link>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Right Column: Episode List + Season Selector (TV Series Only) */}
      {!isMovie && (
        <div className="w-full lg:w-96 shrink-0 flex flex-col gap-6 border-l lg:border-l border-white/5 lg:pl-10">

          {/* Episode List */}
          {episodes.length > 0 ? (
            <div className="flex flex-col gap-4">
              <div className="flex items-center justify-between">
                <h2 className="font-outfit font-bold text-xl text-white">
                  Daftar Episode
                </h2>
                <span className="text-xs text-text-muted bg-bg-elevated px-2.5 py-1 rounded-full border border-white/5">
                  {episodes.length} episode
                </span>
              </div>
              <div className="flex flex-col gap-3 max-h-[60vh] overflow-y-auto pr-2 custom-scrollbar">
                {episodes.map((episode) => {
                  const isActive = episode.episode_number === (currentEpisode as EpisodeRow)?.episode_number;
                  return (
                    <Link
                      key={episode.id}
                      href={`/watch/${movie.slug}?season=${currentSeasonNo}&ep=${episode.episode_number}`}
                      scroll={false}
                      className={`flex gap-4 p-3 rounded-xl border transition-all duration-300 group ${
                        isActive
                          ? "bg-primary-dark/20 border-primary text-white"
                          : "bg-bg-elevated border-white/5 text-text-muted hover:border-white/20 hover:text-white"
                      }`}
                    >
                      {/* Thumbnail */}
                      <div className="w-24 h-14 sm:w-28 sm:h-16 relative rounded-lg overflow-hidden shrink-0 bg-bg-dark border border-white/5 flex items-center justify-center">
                        {episode.still_path ? (
                          <img
                            src={`https://image.tmdb.org/t/p/w185${episode.still_path}`}
                            alt={episode.title || `Episode ${episode.episode_number}`}
                            className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-105"
                          />
                        ) : (
                          <div className="absolute inset-0 bg-gradient-to-br from-primary/25 to-bg-dark flex items-center justify-center text-xs font-semibold font-outfit text-white/40">
                            No Image
                          </div>
                        )}
                        <div className={`absolute bottom-1 right-1 px-1.5 py-0.5 rounded text-[10px] font-bold font-outfit ${
                          isActive ? "bg-primary text-white" : "bg-black/75 text-white/90"
                        }`}>
                          EP {episode.episode_number}
                        </div>
                      </div>

                      {/* Title & Metadata */}
                      <div className="flex flex-col justify-center overflow-hidden min-w-0 flex-1">
                        <h4 className={`font-semibold text-xs sm:text-sm truncate transition-colors duration-200 ${
                          isActive ? "text-white" : "text-white/80 group-hover:text-white"
                        }`}>
                          {episode.title || `Episode ${episode.episode_number}`}
                        </h4>
                        {episode.air_date && (
                          <p className="text-[10px] text-text-muted mt-1 flex items-center gap-1.5">
                            <svg className="w-3.5 h-3.5 opacity-60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                              <line x1="16" y1="2" x2="16" y2="6"/>
                              <line x1="8" y1="2" x2="8" y2="6"/>
                              <line x1="3" y1="10" x2="21" y2="10"/>
                            </svg>
                            {episode.air_date}
                          </p>
                        )}
                      </div>
                    </Link>
                  );
                })}
              </div>
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center py-8 text-center bg-bg-elevated rounded-xl border border-white/5">
              <svg className="w-10 h-10 text-text-muted opacity-30 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5">
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 10.5l4.72-4.72a.75.75 0 011.28.53v11.38a.75.75 0 01-1.28.53l-4.72-4.72M4.5 18.75h9a2.25 2.25 0 002.25-2.25v-9a2.25 2.25 0 00-2.25-2.25h-9A2.25 2.25 0 002.25 7.5v9a2.25 2.25 0 002.25 2.25z" />
              </svg>
              <p className="text-text-muted text-sm">Episode belum tersedia untuk season ini.</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
