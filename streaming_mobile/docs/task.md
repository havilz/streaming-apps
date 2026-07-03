# Daftar Tugas Pengerjaan Flutter (Task List)

Daftar ini digunakan untuk memantau progress pengerjaan aplikasi mobile. Setiap task yang selesai dikerjakan akan diperbarui statusnya di sini.

---

## Progress Global:
- `[x]` Setup Lingkungan Awal (Flutter & Dependensi)
- `[x]` Setup Supabase (Database & Backend)
- `[x]` Implementasi Core & Sistem Desain
- `[x]` Implementasi Fitur Home (Daftar Konten)
- `[x]` Implementasi Fitur Detail & Player
- `[x]` Implementasi Fitur Pencarian & Filter
- `[ ]` Implementasi Sync Otomatis (Edge Function + Cron)
- `[ ]` Pengujian & Finalisasi

---

## Rincian Langkah Pengerjaan:

---

### 1. Setup Lingkungan Awal (Flutter & Dependensi)
- [x] Pastikan Flutter SDK terinstall dan `flutter doctor` berjalan bersih
- [x] Buat dokumen perancangan (`design.md`, `project_structure.md`, `rules.md`, `task.md`)
- [x] Tambahkan dependensi utama ke `pubspec.yaml`:
  - `flutter_riverpod` — state management
  - `supabase_flutter` — koneksi ke Supabase
  - `go_router` — navigasi declarative
  - `cached_network_image` — cache gambar poster dari URL
  - `flutter_dotenv` — membaca file `.env`
  - `video_player` — pemutar video dasar Flutter
  - `chewie` — UI wrapper pemutar video
- [x] Buat file `.env` di root proyek dan tambahkan ke `.gitignore`
- [x] Konfigurasi `analysis_options.yaml` sesuai aturan linting proyek
- [x] Buat struktur folder dasar sesuai `project_structure.md`
- [x] Buat semua file barrel kosong (akan diisi bertahap)

---

### 2. Setup Supabase (Database & Backend)

> **Catatan:** Bagian ini dikerjakan perlahan karena Supabase adalah platform BaaS (Backend-as-a-Service) yang baru. Setiap langkah akan dijelaskan secara rinci.

#### 2a. Membuat Akun & Project Supabase
- [x] Daftar atau masuk ke [supabase.com](https://supabase.com)
- [x] Buat project baru (nama, password database, dan pilih region terdekat — pilih **Southeast Asia (Singapore)** untuk latensi terbaik)
- [x] Catat **Project URL** dan **Anon Public Key** dari menu **Settings > API**
- [x] Simpan kedua nilai tersebut ke file `.env`:
  ```
  SUPABASE_URL=https://xxxx.supabase.co
  SUPABASE_ANON_KEY=eyJxxxx...
  ```

#### 2b. Membuat Skema Database di Supabase
- [x] Buka **Table Editor** atau **SQL Editor** di dashboard Supabase
- [x] Buat tabel `movies` dengan kolom yang sesuai skema SQLite website
- [x] Buat tabel `episodes` dengan kolom yang sesuai skema SQLite website
- [x] Aktifkan **Row Level Security (RLS)** pada kedua tabel
- [x] Buat policy RLS yang mengizinkan `SELECT` untuk `anon` role

#### 2c. Migrasi Data dari SQLite Website
- [x] Buat script `migrate-to-supabase.js` di folder website
- [x] Tambahkan `SUPABASE_SERVICE_KEY` ke `.env` website
- [x] Jalankan script migrasi — hasil: **11.859 movies + 7.521 episodes** berhasil dimigrasikan

#### 2d. Koneksi Supabase ke Flutter
- [x] Inisialisasi Supabase di `main.dart` sebelum `runApp()`
- [x] Buat helper `core/network/supabase_client.dart` untuk mengekspos `Supabase.instance.client`
- [x] Uji koneksi dengan query sederhana (ambil 1 baris dari tabel `movies`) dan tampilkan hasilnya di console

---

### 3. Implementasi Core & Sistem Desain
- [x] Isi `core/constants/app_colors.dart` dengan semua token warna dari `design.md`
- [x] Isi `core/constants/app_typography.dart` dengan skala teks dan font family
- [x] Isi `core/constants/app_spacing.dart` dengan token spacing dan sizing
- [x] Isi `core/constants/app_radius.dart` dengan token border radius
- [x] Isi `core/constants/app_duration.dart` dengan token durasi animasi
- [x] Konfigurasi `ThemeData` dark di `core/theme/app_theme.dart` menggunakan semua konstanta di atas
- [x] Konfigurasi `GoRouter` di `core/router/app_router.dart` (route: home, detail, player, search)
- [x] Buat semua atom dasar: `AppText`, `AppBadge`, `AppShimmer`, `AppDivider`
- [x] Buat `MainScaffold` (template utama dengan `BottomNavigationBar` bergaya glassmorphism)

---

### 4. Implementasi Fitur Home (Daftar Konten)
- [x] Buat `home_repository.dart` — query paginated ke tabel `movies` (LIMIT 20, dengan parameter offset, genre, tahun)
- [x] Buat `home_provider.dart` — Riverpod `AsyncNotifier` yang memanggil repository dan mengelola state daftar konten + filter aktif
- [x] Buat `MovieCard` molecule — card poster film dengan efek glow saat ditekan
- [x] Buat `FilterBar` molecule — baris filter Genre dan Tahun
- [x] Buat `ContentGrid` organism — grid 2 kolom konten dengan shimmer loading
- [x] Buat `HomeScreen` — menggabungkan semua komponen di atas
- [x] Implementasi paginasi: muat lebih banyak konten saat scroll mendekati batas bawah

---

### 5. Implementasi Fitur Detail & Player
- [x] Buat `detail_repository.dart` — query detail satu film + daftar episode dari Supabase
- [x] Buat `detail_provider.dart` — state detail konten + pilihan season aktif
- [x] Buat `EpisodeTile` molecule — item episode dengan thumbnail, judul, tanggal
- [x] Buat `SeasonSelector` molecule — tombol season horizontal scrollable
- [x] Buat `EpisodeList` organism — daftar episode lengkap
- [x] Buat `DetailScreen` — halaman detail film/series (backdrop, sinopsis, genre, daftar episode)
- [x] Buat `PlayerScreen` — pemutar video full-screen dengan loading countdown 15 detik dan efek ambient glow
- [x] Implementasi logika unlock stream: 3-step Pentos flow langsung ke idlix

---

### 6. Implementasi Fitur Pencarian & Filter
- [x] Buat `search_repository.dart` — query `movies` dan `series` dengan filter `title ILIKE '%query%'`, hasil digabung dan diurutkan by rating
- [x] Buat `search_provider.dart` — state pencarian dengan debounce 500ms
- [x] Buat `SearchScreen` — halaman pencarian dengan search bar, debounce, dan hasil real-time
- [x] Filter Genre & Tahun sudah terintegrasi di `home_provider.dart` via `genreId` dari tabel `genres`
  > Catatan: filter Negara dan Network akan ditambahkan setelah data terisi di step 7

---

### 6.5 — Persiapan Database Sebelum Step 7 (one-time, dari komputer)

> Dikerjakan dari website lokal, bukan dari Flutter app.

- [ ] Tambah kolom baru ke tabel Supabase via SQL Editor:
  ```sql
  ALTER TABLE movies ADD COLUMN IF NOT EXISTS status TEXT;
  ALTER TABLE movies ADD COLUMN IF NOT EXISTS country TEXT;
  ALTER TABLE movies ADD COLUMN IF NOT EXISTS networks TEXT;
  ```
- [ ] Update `enrich-details.js` agar bisa enrich kolom `status`, `country`, `networks` dari TMDB
  - Movie: `/movie/{tmdb_id}` → `status`, `production_countries`
  - Series: `/tv/{tmdb_id}` → `status` (Returning Series / Ended), `networks`
- [ ] Jalankan enrich kedua: `node enrich-details.js --mode extra`
  - Filter: `WHERE status IS NULL` — tidak perlu ulang semua konten
- [ ] Verifikasi: cek beberapa baris di Supabase, pastikan `status`, `country`, `networks` terisi

---

### 7. Implementasi Sync Otomatis (Edge Function + Cron)

> **Arsitektur:**
> - idlix → sumber konten & stream URL
> - TMDB → sumber metadata (overview, status, country, networks, dll)
> - Keduanya disambungkan via `tmdb_id` yang ada di setiap konten idlix

#### 7a. Supabase Edge Function `sync-content`
- [ ] Buat Edge Function `sync-content` di Supabase Dashboard → Edge Functions
- [ ] Logic utama (port dari `full-sync.js` website, ditulis dalam Deno/TypeScript):
  - Scrape catalog baru dari idlix `/api/movies` dan `/api/series` (pagination)
  - Untuk setiap konten **baru** (belum ada di Supabase):
    - Fetch detail series dari idlix `/api/series/{slug}` → dapat `seasons`
    - Fetch metadata dari TMDB `/movie/{tmdb_id}` atau `/tv/{tmdb_id}` → dapat `overview`, `status`, `country`, `networks`
    - Upsert ke tabel `movies` dengan data lengkap dari awal
  - Upsert episode baru ke tabel `episodes`
- [ ] Tambahkan endpoint unlock stream di Edge Function yang sama atau terpisah (`unlock-stream`)
  - Port logika `fetchPlayInfo` dari `lib/scraper.ts` website ke Deno
  - Terima parameter: `episodeId`, `slug`, `isMovie`
  - Return: `{ url, subtitles }` atau error

#### 7b. Supabase Cron
- [ ] **Cron Harian** (setiap hari jam 00.00 WIB / 17.00 UTC):
  - Panggil `sync-content` dengan mode `new` — hanya sync konten baru
- [ ] **Cron Mingguan** (setiap Senin jam 02.00 WIB / Minggu 19.00 UTC):
  - Panggil `sync-content` dengan mode `ongoing` — update episode untuk series dengan `status = 'Returning Series'` saja
  - Lebih efisien dari sync semua karena hanya proses series yang masih aktif

#### 7c. Integrasi Flutter → Edge Function
- [ ] Update `detail_repository.dart` — ganti HTTP request langsung ke idlix dengan panggilan ke Supabase Edge Function `unlock-stream`
  - Ini fix permanen untuk masalah Cloudflare 403 di Android
- [ ] Buat `sync_repository.dart` — trigger sync manual via HTTP call ke Edge Function `sync-content`
- [ ] Buat `sync_provider.dart` — state loading/success/error saat sync berjalan
- [ ] Implementasi **pull-to-refresh** di `HomeScreen` — trigger sync manual
- [ ] Implementasi **tombol refresh** di AppBar sebagai alternatif
- [ ] Tampilkan snackbar notifikasi hasil sync

---

### 8. Pengujian & Finalisasi
- [ ] Uji alur lengkap: buka app → browse konten → buka detail → putar video
- [ ] Uji di beberapa ukuran layar (HP kecil, HP besar, tablet)
- [ ] Uji filter Genre, Tahun, Negara, Network
- [ ] Uji pencarian konten
- [ ] Uji sync otomatis (cron) dan sync manual (pull-to-refresh + tombol)
- [ ] Uji player: countdown unlock, video putar, landscape mode
- [ ] Pastikan tidak ada `print()` tersisa di kode
- [ ] Buat `walkthrough.md` yang mendokumentasikan seluruh proses dan checkpoint
- [ ] Pastikan semua linting warning bersih
