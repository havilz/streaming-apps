-- ============================================================
-- Migration 005: Setup pg_net and pg_cron
-- Menyiapkan otomatisasi sinkronisasi harian & mingguan
-- Jalankan di Supabase Dashboard > SQL Editor
-- ============================================================

-- Aktifkan extension yang dibutuhkan
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Cron Harian: Sinkronisasi konten baru
-- Dijalankan setiap hari pada pukul 00:00 WIB (17:00 UTC)
SELECT cron.schedule(
  'sync-new-daily',
  '0 17 * * *',
  $$
  SELECT net.http_post(
    url := 'https://tcosbjernyhyalydiwan.supabase.co/functions/v1/sync-content',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
    body := '{"mode": "new", "secret": "your-sync-secret-here"}'::jsonb
  );
  $$
);

-- Cron Mingguan: Sinkronisasi update series ongoing
-- Dijalankan setiap hari Senin pada pukul 02:00 WIB (Minggu 19:00 UTC)
SELECT cron.schedule(
  'sync-ongoing-weekly',
  '0 19 * * 0',
  $$
  SELECT net.http_post(
    url := 'https://tcosbjernyhyalydiwan.supabase.co/functions/v1/sync-content',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
    body := '{"mode": "ongoing", "secret": "your-sync-secret-here"}'::jsonb
  );
  $$
);
