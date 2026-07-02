-- ============================================================
-- Migration 002: Drop dan recreate tabel dengan skema yang benar
-- Jalankan di Supabase Dashboard > SQL Editor > New Query
-- ============================================================

-- Drop tabel lama (urutan episodes dulu karena ada FK ke movies)
DROP TABLE IF EXISTS episodes;
DROP TABLE IF EXISTS movies;
DROP FUNCTION IF EXISTS update_updated_at CASCADE;

-- ============================================================
-- TABEL: movies (skema final sesuai SQLite website)
-- ============================================================
CREATE TABLE movies (
  id              TEXT PRIMARY KEY,
  tmdb_id         INTEGER,
  imdb_id         TEXT,
  title           TEXT NOT NULL,
  slug            TEXT NOT NULL UNIQUE,
  original_title  TEXT,
  overview        TEXT,
  tagline         TEXT,
  poster_path     TEXT,
  backdrop_path   TEXT,
  logo_path       TEXT,
  content_type    TEXT NOT NULL DEFAULT 'movie',
  release_date    TEXT,
  runtime         INTEGER,
  vote_average    REAL,
  genres          TEXT,
  quality         TEXT,
  seasons         TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_movies_slug         ON movies (slug);
CREATE INDEX idx_movies_content_type ON movies (content_type);
CREATE INDEX idx_movies_release_date ON movies (release_date);

-- ============================================================
-- TABEL: episodes (skema final sesuai SQLite website)
-- ============================================================
CREATE TABLE episodes (
  id                TEXT PRIMARY KEY,
  movie_id          TEXT NOT NULL REFERENCES movies (id) ON DELETE CASCADE,
  season_number     INTEGER NOT NULL DEFAULT 1,
  episode_number    INTEGER NOT NULL DEFAULT 1,
  title             TEXT,
  overview          TEXT,
  still_path        TEXT,
  runtime           INTEGER,
  air_date          TEXT,
  video_url         TEXT,
  video_type        TEXT DEFAULT 'unknown',
  video_fetched_at  TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (movie_id, season_number, episode_number)
);

CREATE INDEX idx_episodes_movie_id ON episodes (movie_id);
CREATE INDEX idx_episodes_season   ON episodes (movie_id, season_number);

-- ============================================================
-- FUNGSI & TRIGGER: auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_movies_updated_at
  BEFORE UPDATE ON movies
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_episodes_updated_at
  BEFORE UPDATE ON episodes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE movies   ENABLE ROW LEVEL SECURITY;
ALTER TABLE episodes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on movies"
  ON movies FOR SELECT TO anon USING (true);

CREATE POLICY "Allow public read on episodes"
  ON episodes FOR SELECT TO anon USING (true);

CREATE POLICY "Allow service role full access on movies"
  ON movies FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "Allow service role full access on episodes"
  ON episodes FOR ALL TO service_role
  USING (true) WITH CHECK (true);
