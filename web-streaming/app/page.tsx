import Link from "next/link";
import { getDb } from "@/lib/db";
import FilterDropdowns from "@/app/components/FilterDropdowns";

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
  country: string | null;
}

interface PageProps {
  searchParams: Promise<{
    type?: string;
    q?: string;
    page?: string;
    genre?: string;
    year?: string;
  }>;
}

const PAGE_SIZE = 40;

// Static filter options
const GENRES = [
  "Action", "Adventure", "Animation", "Comedy", "Crime",
  "Documentary", "Drama", "Family", "Fantasy", "Horror",
  "Mystery", "Romance", "Sci-Fi", "Thriller", "War",
];

export default async function Home({ searchParams }: PageProps) {
  const { type, q, page: pageParam, genre, year } = await searchParams;
  const db = getDb();
  const currentPage = Math.max(1, parseInt(pageParam || "1", 10));
  const offset = (currentPage - 1) * PAGE_SIZE;

  // Build dynamic SQL query
  let baseQuery = "FROM movies";
  const conditions: string[] = [];
  const params: Record<string, unknown> = {};

  if (type && (type === "movie" || type === "series")) {
    conditions.push("content_type = @type");
    params.type = type;
  }

  if (q) {
    conditions.push("(title LIKE @search OR overview LIKE @search)");
    params.search = `%${q}%`;
  }

  if (genre) {
    conditions.push("genres LIKE @genre");
    params.genre = `%"name":"${genre}"%`;
  }

  if (year) {
    conditions.push("substr(release_date, 1, 4) = @year");
    params.year = year;
  }

  if (conditions.length > 0) {
    baseQuery += " WHERE " + conditions.join(" AND ");
  }

  // Paginated query
  const movies = db
    .prepare(`SELECT * ${baseQuery} ORDER BY created_at DESC LIMIT @limit OFFSET @offset`)
    .all({ ...params, limit: PAGE_SIZE, offset }) as MovieRow[];

  // Total count for pagination
  const { total } = db
    .prepare(`SELECT COUNT(*) as total ${baseQuery}`)
    .get(params) as { total: number };

  const totalPages = Math.ceil(total / PAGE_SIZE);

  // Featured banner (only on page 1 without filters)
  const isFiltered = q || genre || year;
  const featuredPool = db
    .prepare("SELECT * FROM movies WHERE backdrop_path IS NOT NULL AND overview IS NOT NULL ORDER BY created_at DESC LIMIT 20")
    .all() as MovieRow[];
  const featured = featuredPool[Math.floor(Date.now() / 3600000) % featuredPool.length] ?? featuredPool[0];

  // Build URL helpers for filter and pagination
  function buildUrl(overrides: Record<string, string | undefined>) {
    const p = new URLSearchParams();
    const merged = { type, q, page: undefined, genre, year, ...overrides };
    for (const [k, v] of Object.entries(merged)) {
      if (v) p.set(k, v);
    }
    const qs = p.toString();
    return qs ? `/?${qs}` : "/";
  }

  function pageUrl(p: number) {
    return buildUrl({ page: p > 1 ? String(p) : undefined });
  }

  // Build available years (current year down to 2000)
  const currentYear = new Date().getFullYear();
  const YEARS = Array.from({ length: currentYear - 1999 }, (_, i) => String(currentYear - i));

  return (
    <div className="min-h-screen pb-20">
      {/* Hero Banner */}
      {featured && currentPage === 1 && !isFiltered && (
        <section className="relative w-full h-[70vh] sm:h-[80vh] overflow-hidden flex items-center">
          <div
            className="absolute inset-0 bg-cover bg-center"
            style={{ backgroundImage: `url(https://image.tmdb.org/t/p/original${featured.backdrop_path})` }}
          />
          <div className="absolute inset-0 bg-gradient-to-t from-bg-dark via-bg-dark/70 to-transparent" />
          <div className="absolute inset-0 hero-gradient" />

          <div className="relative z-10 max-w-[1400px] w-full mx-auto px-4 sm:px-6 lg:px-10 flex flex-col items-start gap-4">
            <div className="flex items-center gap-2">
              <span className="badge badge-quality">{featured.quality || "HD"}</span>
              <span className="badge badge-type">
                {featured.content_type === "series" ? "Serial TV" : "Film"}
              </span>
              {featured.vote_average && (
                <span className="flex items-center gap-1 text-sm font-semibold text-amber-400">
                  ★ {Number(featured.vote_average).toFixed(1)}
                </span>
              )}
            </div>

            <h1 className="text-4xl sm:text-6xl font-bold font-outfit max-w-2xl tracking-tight leading-none text-white">
              {featured.title}
            </h1>

            {featured.tagline && (
              <p className="text-lg italic text-text-muted font-light max-w-2xl">
                &ldquo;{featured.tagline}&rdquo;
              </p>
            )}

            {featured.overview && (
              <p className="text-sm sm:text-base text-text-muted max-w-xl line-clamp-3 leading-relaxed">
                {featured.overview}
              </p>
            )}

            <div className="mt-4">
              <Link href={`/watch/${featured.slug}`} className="btn-play">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M8 5v14l11-7z" />
                </svg>
                Putar Sekarang
              </Link>
            </div>
          </div>
        </section>
      )}

      {/* Main Content */}
      <div className="max-w-[1400px] mx-auto px-4 sm:px-6 lg:px-10 mt-12">

        {/* Top Nav: Tabs + Search */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-6 mb-6 border-b border-white/5 pb-6">
          {/* Capsule tabs */}
          <div className="flex items-center gap-2 p-1 bg-bg-elevated rounded-full border border-white/5 max-w-max self-center sm:self-auto">
            <Link
              href={buildUrl({ type: undefined, page: undefined })}
              className={`px-5 py-2 text-sm font-semibold rounded-full transition-all duration-300 ${
                !type ? "bg-primary text-white" : "text-text-muted hover:text-white"
              }`}
            >
              Semua
            </Link>
            <Link
              href={buildUrl({ type: "movie", page: undefined })}
              className={`px-5 py-2 text-sm font-semibold rounded-full transition-all duration-300 ${
                type === "movie" ? "bg-primary text-white" : "text-text-muted hover:text-white"
              }`}
            >
              Film
            </Link>
            <Link
              href={buildUrl({ type: "series", page: undefined })}
              className={`px-5 py-2 text-sm font-semibold rounded-full transition-all duration-300 ${
                type === "series" ? "bg-primary text-white" : "text-text-muted hover:text-white"
              }`}
            >
              Serial TV
            </Link>
          </div>

          {/* Search bar */}
          <form method="GET" action="/" className="relative flex-1 max-w-md">
            {type && <input type="hidden" name="type" value={type} />}
            {genre && <input type="hidden" name="genre" value={genre} />}
            {year && <input type="hidden" name="year" value={year} />}
            <input
              type="text"
              name="q"
              defaultValue={q || ""}
              placeholder="Cari film atau serial..."
              className="w-full h-11 pl-11 pr-4 bg-bg-elevated text-sm border border-white/5 rounded-full text-white placeholder-text-muted focus:outline-none focus:border-primary/50 transition-colors"
            />
            <div className="absolute left-4 top-1/2 -translate-y-1/2 text-text-muted">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="11" cy="11" r="8" />
                <path d="m21 21-4.3-4.3" />
              </svg>
            </div>
          </form>
        </div>

        {/* Filter Dropdowns Row — Client Component (handles onChange/router.push) */}
        <FilterDropdowns
          type={type}
          q={q}
          genre={genre}
          year={year}
          genres={GENRES}
          years={YEARS}
        />

        {/* Section title & count */}
        <div className="flex items-baseline justify-between mb-6">
          <h2 className="section-title">
            {q
              ? `Hasil pencarian untuk "${q}"`
              : genre
              ? `Genre: ${genre}`
              : year
              ? `Tahun ${year}`
              : type === "movie"
              ? "Semua Film"
              : type === "series"
              ? "Semua Serial TV"
              : "Rekomendasi Terbaru"}
          </h2>
          <span className="text-sm text-text-muted">
            {total.toLocaleString("id-ID")} konten • Halaman {currentPage}/{totalPages}
          </span>
        </div>

        {/* Movies Grid */}
        {movies.length > 0 ? (
          <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-6">
            {movies.map((movie) => {
              const genresList = movie.genres ? JSON.parse(movie.genres) : [];
              const releaseYear = movie.release_date
                ? new Date(movie.release_date).getFullYear()
                : null;

              return (
                <Link
                  key={movie.id}
                  href={`/watch/${movie.slug}`}
                  className="movie-card group aspect-[2/3]"
                >
                  <div
                    className="w-full h-full bg-cover bg-center rounded-xl"
                    style={{
                      backgroundImage: `url(https://image.tmdb.org/t/p/w342${movie.poster_path})`,
                    }}
                  />
                  <div className="overlay rounded-xl">
                    <span className="badge badge-quality absolute top-3 right-3">
                      {movie.quality || "HD"}
                    </span>
                    <div className="flex flex-col gap-1.5">
                      <h3 className="font-outfit font-semibold text-base text-white leading-snug line-clamp-2">
                        {movie.title}
                      </h3>
                      <div className="flex items-center justify-between text-xs text-text-muted">
                        <span>{releaseYear || "N/A"}</span>
                        {movie.vote_average && (
                          <span className="text-amber-400 font-semibold">
                            ★ {Number(movie.vote_average).toFixed(1)}
                          </span>
                        )}
                      </div>
                      <p className="text-[11px] text-text-muted line-clamp-1">
                        {genresList.map((g: { name: string }) => g.name).join(", ")}
                      </p>
                    </div>
                  </div>
                </Link>
              );
            })}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-20 text-center">
            <svg className="text-text-muted mb-4 opacity-30" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="10" />
              <path d="M16 16s-1.5-2-4-2-4 2-4 2" />
              <line x1="9" x2="9.01" y1="9" y2="9" />
              <line x1="15" x2="15.01" y1="9" y2="9" />
            </svg>
            <p className="text-text-muted text-base">Tidak ada konten ditemukan.</p>
            {(genre || year) && (
              <Link
                href={buildUrl({ genre: undefined, year: undefined, page: undefined })}
                className="mt-4 text-sm text-primary hover:text-white transition-colors"
              >
                Reset semua filter
              </Link>
            )}
          </div>
        )}

        {/* Pagination Controls */}
        {totalPages > 1 && (
          <div className="flex items-center justify-center gap-2 mt-14">
            {currentPage > 1 ? (
              <Link
                href={pageUrl(currentPage - 1)}
                className="flex items-center gap-2 px-5 py-2.5 rounded-full bg-bg-elevated border border-white/10 text-sm font-semibold text-white hover:bg-bg-card hover:border-primary/40 transition-all duration-200"
              >
                ← Sebelumnya
              </Link>
            ) : (
              <span className="px-5 py-2.5 rounded-full bg-bg-elevated border border-white/5 text-sm text-text-muted opacity-40 cursor-not-allowed">
                ← Sebelumnya
              </span>
            )}

            <div className="flex items-center gap-1">
              {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                let p: number;
                if (totalPages <= 5) {
                  p = i + 1;
                } else if (currentPage <= 3) {
                  p = i + 1;
                } else if (currentPage >= totalPages - 2) {
                  p = totalPages - 4 + i;
                } else {
                  p = currentPage - 2 + i;
                }
                return (
                  <Link
                    key={p}
                    href={pageUrl(p)}
                    className={`w-10 h-10 flex items-center justify-center rounded-full text-sm font-semibold transition-all duration-200 ${
                      p === currentPage
                        ? "bg-primary text-white shadow-lg shadow-primary/30"
                        : "bg-bg-elevated border border-white/10 text-text-muted hover:text-white hover:border-primary/40"
                    }`}
                  >
                    {p}
                  </Link>
                );
              })}
            </div>

            {currentPage < totalPages ? (
              <Link
                href={pageUrl(currentPage + 1)}
                className="flex items-center gap-2 px-5 py-2.5 rounded-full bg-bg-elevated border border-white/10 text-sm font-semibold text-white hover:bg-bg-card hover:border-primary/40 transition-all duration-200"
              >
                Selanjutnya →
              </Link>
            ) : (
              <span className="px-5 py-2.5 rounded-full bg-bg-elevated border border-white/5 text-sm text-text-muted opacity-40 cursor-not-allowed">
                Selanjutnya →
              </span>
            )}
          </div>
        )}

        {totalPages > 1 && (
          <p className="text-center text-xs text-text-muted mt-4 opacity-60">
            Menampilkan {offset + 1}–{Math.min(offset + PAGE_SIZE, total)} dari {total.toLocaleString("id-ID")} konten
          </p>
        )}
      </div>
    </div>
  );
}
