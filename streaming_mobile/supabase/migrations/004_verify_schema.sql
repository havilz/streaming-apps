-- ============================================================
-- Migration 004: Verifikasi schema dan tambah index tambahan
-- Jalankan di Supabase Dashboard > SQL Editor > New Query
-- ============================================================

-- Verifikasi semua tabel ada
DO $$
DECLARE
  tables TEXT[] := ARRAY[
    'movies', 'series', 'episodes',
    'genres', 'countries', 'networks',
    'movie_genres', 'series_genres',
    'movie_countries', 'series_countries',
    'series_networks'
  ];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = t
    ) THEN
      RAISE EXCEPTION 'Tabel % tidak ditemukan!', t;
    END IF;
  END LOOP;
  RAISE NOTICE '✅ Semua tabel ada dan siap';
END $$;

-- Tambah index untuk pencarian title (full-text search lebih cepat)
CREATE INDEX IF NOT EXISTS idx_movies_title_search
  ON movies USING gin(to_tsvector('english', title));

CREATE INDEX IF NOT EXISTS idx_series_title_search
  ON series USING gin(to_tsvector('english', title));

-- Tambah index untuk filter status (untuk cron mingguan ongoing series)
CREATE INDEX IF NOT EXISTS idx_series_status_ongoing
  ON series (status) WHERE status = 'Returning Series';
