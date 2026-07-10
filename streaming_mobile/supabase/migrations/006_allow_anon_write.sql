-- ============================================================
-- Migration 006: Allow anon writes for client-side syncing
-- Jalankan di Supabase Dashboard > SQL Editor atau supabase db push
-- ============================================================

-- RLS policy untuk movies
DROP POLICY IF EXISTS "anon write movies" ON movies;
CREATE POLICY "anon write movies" ON movies FOR ALL TO anon USING (true) WITH CHECK (true);

-- RLS policy untuk series
DROP POLICY IF EXISTS "anon write series" ON series;
CREATE POLICY "anon write series" ON series FOR ALL TO anon USING (true) WITH CHECK (true);

-- RLS policy untuk episodes
DROP POLICY IF EXISTS "anon write episodes" ON episodes;
CREATE POLICY "anon write episodes" ON episodes FOR ALL TO anon USING (true) WITH CHECK (true);

-- RLS policy untuk genres (jika dibutuhkan)
DROP POLICY IF EXISTS "anon write genres" ON genres;
CREATE POLICY "anon write genres" ON genres FOR ALL TO anon USING (true) WITH CHECK (true);

-- RLS policy untuk countries (jika dibutuhkan)
DROP POLICY IF EXISTS "anon write countries" ON countries;
CREATE POLICY "anon write countries" ON countries FOR ALL TO anon USING (true) WITH CHECK (true);

-- RLS policy untuk networks (jika dibutuhkan)
DROP POLICY IF EXISTS "anon write networks" ON networks;
CREATE POLICY "anon write networks" ON networks FOR ALL TO anon USING (true) WITH CHECK (true);

-- RLS policy untuk movie_genres
DROP POLICY IF EXISTS "anon write movie_genres" ON movie_genres;
CREATE POLICY "anon write movie_genres" ON movie_genres FOR ALL TO anon USING (true) WITH CHECK (true);

-- RLS policy untuk series_genres
DROP POLICY IF EXISTS "anon write series_genres" ON series_genres;
CREATE POLICY "anon write series_genres" ON series_genres FOR ALL TO anon USING (true) WITH CHECK (true);

-- RLS policy untuk movie_countries
DROP POLICY IF EXISTS "anon write movie_countries" ON movie_countries;
CREATE POLICY "anon write movie_countries" ON movie_countries FOR ALL TO anon USING (true) WITH CHECK (true);

-- RLS policy untuk series_countries
DROP POLICY IF EXISTS "anon write series_countries" ON series_countries;
CREATE POLICY "anon write series_countries" ON series_countries FOR ALL TO anon USING (true) WITH CHECK (true);

-- RLS policy untuk series_networks
DROP POLICY IF EXISTS "anon write series_networks" ON series_networks;
CREATE POLICY "anon write series_networks" ON series_networks FOR ALL TO anon USING (true) WITH CHECK (true);
