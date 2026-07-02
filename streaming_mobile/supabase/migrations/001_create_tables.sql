-- ============================================================
-- Migration 001: Buat tabel movies dan episodes
-- Skema ini identik dengan SQLite di website (lib/db.ts)
-- Jalankan file ini di Supabase Dashboard > SQL Editor > New Query
-- ============================================================

-- ============================================================
-- TABEL: movies
-- ============================================================
CREATE TABLE IF NOT EXISTS movies (
  id              TEXT PRIMARY KEY,         -- ID dari idlix (bukan auto-increment)
  tmdb_id         INTEGER,
  imdb_id         TEXT,
  title           TEXT NOT NULL,
  slug            TEXT NOT NULL UNIQUE,
  original_title  TEXT,
  overview        TEXT,
  tagline         TEXT,
  poster_path     TEXT,                     -- URL poster dari TMDB
  backdrop_path   TEXT,                     -- URL backdrop dari TMDB
  logo_path       TEXT,
  content_type    TEXT NOT NULL DEFAULT 'movie', -- 'movie' atau 'series'
  release_date    TEXT,                     -- format ISO: '2024-05-15'
  runtime         INTEGER,                  -- durasi dalam menit
  vote_average    REAL,                     -- rating (0.0 - 10.0)
  genres          TEXT,                     -- JSON string: [{"name":"Action"}]
  quality         TEXT,                     -- 'HD', '4K', dll
  seasons         TEXT,                     -- JSON string: daftar season untuk series
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index untuk performa query
CREATE INDEX IF NOT EXISTS idx_movies_slug         ON movies (slug);
CREATE INDEX IF NOT EXISTS idx_movies_content_type ON movies (content_type);
CREATE INDEX IF NOT EXISTS idx_movies_release_date ON movies (release_date);

-- ============================================================
-- TABEL: episodes
-- ============================================================
CREATE TABLE IF NOT EXISTS episodes (
  id                TEXT PRIMARY KEY,       -- ID episode dari idlix
  movie_id          TEXT NOT NULL REFERENCES movies (id) ON DELETE CASCADE,
  season_number     INTEGER NOT NULL DEFAULT 1,
  episode_number    INTEGER NOT NULL DEFAULT 1,
  title             TEXT,
  overview          TEXT,
  still_path        TEXT,                   -- URL thumbnail episode
  runtime           INTEGER,               -- durasi episode dalam menit
  air_date          TEXT,                   -- format ISO: '2024-05-15'
  video_url         TEXT,                   -- URL stream yang sudah di-unlock
  video_type        TEXT DEFAULT 'unknown', -- tipe video (hls, embed, dll)
  video_fetched_at  TEXT,                   -- timestamp terakhir fetch video URL
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (movie_id, season_number, episode_number)
);

-- Index untuk performa query
CREATE INDEX IF NOT EXISTS idx_episodes_movie_id ON episodes (movie_id);
CREATE INDEX IF NOT EXISTS idx_episodes_season   ON episodes (movie_id, season_number);

-- ============================================================
-- FUNGSI: auto-update kolom updated_at saat row diupdate
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_movies_updated_at
  BEFORE UPDATE ON movies
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trigger_episodes_updated_at
  BEFORE UPDATE ON episodes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE movies   ENABLE ROW LEVEL SECURITY;
ALTER TABLE episodes ENABLE ROW LEVEL SECURITY;

-- anon (Flutter app) hanya boleh baca
CREATE POLICY "Allow public read on movies"
  ON movies FOR SELECT TO anon USING (true);

CREATE POLICY "Allow public read on episodes"
  ON episodes FOR SELECT TO anon USING (true);

-- service_role (Edge Function sync) boleh semua operasi
CREATE POLICY "Allow service role full access on movies"
  ON movies FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "Allow service role full access on episodes"
  ON episodes FOR ALL TO service_role
  USING (true) WITH CHECK (true);
