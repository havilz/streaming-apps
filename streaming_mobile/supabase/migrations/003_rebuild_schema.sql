-- ============================================================
-- Migration 003: Rebuild schema — normalized tables
-- DROP semua tabel lama, buat struktur baru yang lebih rapih
-- Jalankan di Supabase Dashboard > SQL Editor > New Query
-- ============================================================

-- ── Drop tabel lama (urutan penting karena ada FK) ──────────
DROP TABLE IF EXISTS episodes  CASCADE;
DROP TABLE IF EXISTS movies    CASCADE;
DROP FUNCTION IF EXISTS update_updated_at CASCADE;

-- ============================================================
-- TABEL REFERENSI
-- ============================================================

-- Genres
CREATE TABLE genres (
  id    SMALLSERIAL PRIMARY KEY,
  name  TEXT NOT NULL UNIQUE
);

-- Countries
CREATE TABLE countries (
  id    SMALLSERIAL PRIMARY KEY,
  code  TEXT,          -- ISO 3166-1 alpha-2, contoh: 'US', 'KR', 'ID'
  name  TEXT NOT NULL UNIQUE
);

-- Networks (platform/jaringan TV: Netflix, HBO, dll)
CREATE TABLE networks (
  id        SMALLSERIAL PRIMARY KEY,
  name      TEXT NOT NULL UNIQUE,
  logo_path TEXT          -- path relatif TMDB, nullable
);

-- ============================================================
-- TABEL UTAMA: movies
-- ============================================================
CREATE TABLE movies (
  id             TEXT PRIMARY KEY,   -- ID dari idlix
  tmdb_id        INTEGER,
  imdb_id        TEXT,
  title          TEXT NOT NULL,
  slug           TEXT NOT NULL UNIQUE,
  original_title TEXT,
  overview       TEXT,
  poster_path    TEXT,
  backdrop_path  TEXT,
  release_date   TEXT,               -- format ISO: '2024-05-15'
  runtime        INTEGER,            -- menit
  vote_average   REAL,
  quality        TEXT,
  status         TEXT,               -- 'Released', 'In Production', dll
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_movies_slug         ON movies (slug);
CREATE INDEX idx_movies_release_date ON movies (release_date);
CREATE INDEX idx_movies_status       ON movies (status);

-- ============================================================
-- TABEL UTAMA: series
-- ============================================================
CREATE TABLE series (
  id                TEXT PRIMARY KEY,  -- ID dari idlix
  tmdb_id           INTEGER,
  imdb_id           TEXT,
  title             TEXT NOT NULL,
  slug              TEXT NOT NULL UNIQUE,
  original_title    TEXT,
  overview          TEXT,
  poster_path       TEXT,
  backdrop_path     TEXT,
  first_air_date    TEXT,
  vote_average      REAL,
  quality           TEXT,
  status            TEXT,              -- 'Returning Series', 'Ended', 'Canceled'
  number_of_seasons INTEGER,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_series_slug         ON series (slug);
CREATE INDEX idx_series_first_air    ON series (first_air_date);
CREATE INDEX idx_series_status       ON series (status);

-- ============================================================
-- TABEL UTAMA: episodes
-- ============================================================
CREATE TABLE episodes (
  id               TEXT PRIMARY KEY,   -- ID episode dari idlix
  series_id        TEXT NOT NULL REFERENCES series (id) ON DELETE CASCADE,
  season_number    INTEGER NOT NULL DEFAULT 1,
  episode_number   INTEGER NOT NULL DEFAULT 1,
  title            TEXT,
  overview         TEXT,
  still_path       TEXT,
  runtime          INTEGER,
  air_date         TEXT,
  video_url        TEXT,
  video_type       TEXT DEFAULT 'unknown',
  video_fetched_at TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (series_id, season_number, episode_number)
);

CREATE INDEX idx_episodes_series_id ON episodes (series_id);
CREATE INDEX idx_episodes_season    ON episodes (series_id, season_number);

-- ============================================================
-- TABEL RELASI: movie ↔ genre
-- ============================================================
CREATE TABLE movie_genres (
  movie_id  TEXT     NOT NULL REFERENCES movies  (id) ON DELETE CASCADE,
  genre_id  SMALLINT NOT NULL REFERENCES genres  (id) ON DELETE CASCADE,
  PRIMARY KEY (movie_id, genre_id)
);

CREATE INDEX idx_movie_genres_genre ON movie_genres (genre_id);

-- ============================================================
-- TABEL RELASI: series ↔ genre
-- ============================================================
CREATE TABLE series_genres (
  series_id TEXT     NOT NULL REFERENCES series  (id) ON DELETE CASCADE,
  genre_id  SMALLINT NOT NULL REFERENCES genres  (id) ON DELETE CASCADE,
  PRIMARY KEY (series_id, genre_id)
);

CREATE INDEX idx_series_genres_genre ON series_genres (genre_id);

-- ============================================================
-- TABEL RELASI: movie ↔ country
-- ============================================================
CREATE TABLE movie_countries (
  movie_id   TEXT     NOT NULL REFERENCES movies    (id) ON DELETE CASCADE,
  country_id SMALLINT NOT NULL REFERENCES countries (id) ON DELETE CASCADE,
  PRIMARY KEY (movie_id, country_id)
);

-- ============================================================
-- TABEL RELASI: series ↔ country
-- ============================================================
CREATE TABLE series_countries (
  series_id  TEXT     NOT NULL REFERENCES series    (id) ON DELETE CASCADE,
  country_id SMALLINT NOT NULL REFERENCES countries (id) ON DELETE CASCADE,
  PRIMARY KEY (series_id, country_id)
);

-- ============================================================
-- TABEL RELASI: series ↔ network
-- ============================================================
CREATE TABLE series_networks (
  series_id  TEXT     NOT NULL REFERENCES series   (id) ON DELETE CASCADE,
  network_id SMALLINT NOT NULL REFERENCES networks (id) ON DELETE CASCADE,
  PRIMARY KEY (series_id, network_id)
);

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

CREATE TRIGGER trg_movies_updated_at
  BEFORE UPDATE ON movies
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_series_updated_at
  BEFORE UPDATE ON series
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_episodes_updated_at
  BEFORE UPDATE ON episodes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE movies          ENABLE ROW LEVEL SECURITY;
ALTER TABLE series          ENABLE ROW LEVEL SECURITY;
ALTER TABLE episodes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE genres          ENABLE ROW LEVEL SECURITY;
ALTER TABLE countries       ENABLE ROW LEVEL SECURITY;
ALTER TABLE networks        ENABLE ROW LEVEL SECURITY;
ALTER TABLE movie_genres    ENABLE ROW LEVEL SECURITY;
ALTER TABLE series_genres   ENABLE ROW LEVEL SECURITY;
ALTER TABLE movie_countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE series_countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE series_networks ENABLE ROW LEVEL SECURITY;

-- anon: hanya bisa baca
CREATE POLICY "anon read movies"           ON movies           FOR SELECT TO anon USING (true);
CREATE POLICY "anon read series"           ON series           FOR SELECT TO anon USING (true);
CREATE POLICY "anon read episodes"         ON episodes         FOR SELECT TO anon USING (true);
CREATE POLICY "anon read genres"           ON genres           FOR SELECT TO anon USING (true);
CREATE POLICY "anon read countries"        ON countries        FOR SELECT TO anon USING (true);
CREATE POLICY "anon read networks"         ON networks         FOR SELECT TO anon USING (true);
CREATE POLICY "anon read movie_genres"     ON movie_genres     FOR SELECT TO anon USING (true);
CREATE POLICY "anon read series_genres"    ON series_genres    FOR SELECT TO anon USING (true);
CREATE POLICY "anon read movie_countries"  ON movie_countries  FOR SELECT TO anon USING (true);
CREATE POLICY "anon read series_countries" ON series_countries FOR SELECT TO anon USING (true);
CREATE POLICY "anon read series_networks"  ON series_networks  FOR SELECT TO anon USING (true);

-- service_role: akses penuh (untuk Edge Function)
CREATE POLICY "service full movies"           ON movies           FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service full series"           ON series           FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service full episodes"         ON episodes         FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service full genres"           ON genres           FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service full countries"        ON countries        FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service full networks"         ON networks         FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service full movie_genres"     ON movie_genres     FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service full series_genres"    ON series_genres    FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service full movie_countries"  ON movie_countries  FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service full series_countries" ON series_countries FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service full series_networks"  ON series_networks  FOR ALL TO service_role USING (true) WITH CHECK (true);
