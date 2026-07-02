# Daftar Tugas Pengerjaan Flutter (Task List)

Daftar ini digunakan untuk memantau progress pengerjaan aplikasi mobile. Setiap task yang selesai dikerjakan akan diperbarui statusnya di sini.

---

## Progress Global:
- `[x]` Setup Lingkungan Awal (Flutter & Dependensi)
- `[ ]` Setup Supabase (Database & Backend)
- `[ ]` Implementasi Core & Sistem Desain
- `[ ]` Implementasi Fitur Home (Daftar Konten)
- `[ ]` Implementasi Fitur Detail & Player
- `[ ]` Implementasi Fitur Pencarian & Filter
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
- [ ] Daftar atau masuk ke [supabase.com](https://supabase.com)
- [ ] Buat project baru (nama, password database, dan pilih region terdekat — pilih **Southeast Asia (Singapore)** untuk latensi terbaik)
- [ ] Catat **Project URL** dan **Anon Public Key** dari menu **Settings > API**
- [ ] Simpan kedua nilai tersebut ke file `.env`:
  ```
  SUPABASE_URL=https://xxxx.supabase.co
  SUPABASE_ANON_KEY=eyJxxxx...
  ```

#### 2b. Membuat Skema Database di Supabase
- [ ] Buka **Table Editor** atau **SQL Editor** di dashboard Supabase
- [ ] Buat tabel `movies` dengan kolom berikut:
  - `id` (int8, primary key, auto-increment)
  - `slug` (text, unique, not null) — ID unik konten
  - `title` (text, not null)
  - `content_type` (text) — `'movie'` atau `'series'`
  - `poster_url` (text) — URL gambar poster dari TMDB
  - `backdrop_url` (text) — URL gambar backdrop
  - `synopsis` (text)
  - `genres` (jsonb) — array genre, contoh: `[{"name":"Action"}]`
  - `release_date` (text) — format ISO date, contoh: `'2024-05-15'`
  - `seasons` (jsonb, nullable) — daftar season untuk series
  - `stream_url` (text, nullable) — URL stream yang sudah di-unlock
  - `created_at` (timestamptz, default: `now()`)
- [ ] Buat tabel `episodes` dengan kolom berikut:
  - `id` (int8, primary key, auto-increment)
  - `movie_id` (int8, foreign key ke `movies.id`)
  - `season_number` (int4)
  - `episode_number` (int4)
  - `title` (text)
  - `still_url` (text) — URL thumbnail episode
  - `air_date` (text)
  - `episode_id` (text) — ID episode dari sumber konten asli
  - `stream_url` (text, nullable)
  - `created_at` (timestamptz, default: `now()`)
- [ ] Aktifkan **Row Level Security (RLS)** pada kedua tabel
- [ ] Buat policy RLS yang mengizinkan `SELECT` untuk `anon` role (agar aplikasi bisa membaca data)

#### 2c. Migrasi Data dari SQLite Website
- [ ] Ekspor data dari database SQLite website (`dev.db`) ke format CSV atau SQL
- [ ] Import data ke tabel Supabase menggunakan fitur **Import CSV** di Table Editor atau via SQL Editor
- [ ] Verifikasi jumlah baris setelah import sesuai dengan data di SQLite

#### 2d. Koneksi Supabase ke Flutter
- [ ] Inisialisasi Supabase di `main.dart` sebelum `runApp()`:
  ```dart
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  ```
- [ ] Buat helper `core/network/supabase_client.dart` untuk mengekspos `Supabase.instance.client`
- [ ] Uji koneksi dengan query sederhana (ambil 1 baris dari tabel `movies`) dan tampilkan hasilnya di console

---

### 3. Implementasi Core & Sistem Desain
- [ ] Isi `core/constants/app_colors.dart` dengan semua token warna dari `design.md`
- [ ] Isi `core/constants/app_typography.dart` dengan skala teks dan font family
- [ ] Isi `core/constants/app_spacing.dart` dengan token spacing dan sizing
- [ ] Isi `core/constants/app_radius.dart` dengan token border radius
- [ ] Isi `core/constants/app_duration.dart` dengan token durasi animasi
- [ ] Konfigurasi `ThemeData` dark di `core/theme/app_theme.dart` menggunakan semua konstanta di atas
- [ ] Konfigurasi `GoRouter` di `core/router/app_router.dart` (route: home, detail, player, search)
- [ ] Buat semua atom dasar: `AppText`, `AppBadge`, `AppShimmer`, `AppDivider`
- [ ] Buat `MainScaffold` (template utama dengan `BottomNavigationBar` bergaya glassmorphism)

---

### 4. Implementasi Fitur Home (Daftar Konten)
- [ ] Buat `home_repository.dart` — query paginated ke tabel `movies` (LIMIT 20, dengan parameter offset, genre, tahun)
- [ ] Buat `home_provider.dart` — Riverpod `AsyncNotifier` yang memanggil repository dan mengelola state daftar konten + filter aktif
- [ ] Buat `MovieCard` molecule — card poster film dengan efek glow saat ditekan
- [ ] Buat `FilterBar` molecule — baris filter Genre dan Tahun
- [ ] Buat `ContentGrid` organism — grid 2 kolom konten dengan shimmer loading
- [ ] Buat `HomeScreen` — menggabungkan semua komponen di atas
- [ ] Implementasi paginasi: muat lebih banyak konten saat scroll mendekati batas bawah

---

### 5. Implementasi Fitur Detail & Player
- [ ] Buat `detail_repository.dart` — query detail satu film + daftar episode dari Supabase
- [ ] Buat `detail_provider.dart` — state detail konten + pilihan season aktif
- [ ] Buat `EpisodeTile` molecule — item episode dengan thumbnail, judul, tanggal
- [ ] Buat `SeasonSelector` molecule — tombol season horizontal scrollable
- [ ] Buat `EpisodeList` organism — daftar episode lengkap
- [ ] Buat `DetailScreen` — halaman detail film/series (backdrop, sinopsis, genre, daftar episode)
- [ ] Buat `PlayerScreen` — pemutar video full-screen dengan loading countdown 15 detik dan efek ambient glow
- [ ] Implementasi logika unlock stream: panggil Supabase Edge Function atau endpoint yang sama dengan website

---

### 6. Implementasi Fitur Pencarian & Filter
- [ ] Buat `search_repository.dart` — query `movies` dengan filter `title ILIKE '%query%'`
- [ ] Buat `search_provider.dart` — state pencarian dengan debounce input
- [ ] Buat `SearchScreen` — halaman pencarian dengan search bar dan hasil real-time
- [ ] Integrasikan filter Genre & Tahun dari `FilterBar` ke query di `home_provider.dart`

---

### 7. Pengujian & Finalisasi
- [ ] Uji alur lengkap: buka app → browse konten → buka detail → putar video
- [ ] Uji di beberapa ukuran layar (HP kecil, HP besar, tablet)
- [ ] Uji filter Genre dan Tahun
- [ ] Uji pencarian konten
- [ ] Pastikan tidak ada `print()` tersisa di kode
- [ ] Buat `walkthrough.md` yang mendokumentasikan seluruh proses dan checkpoint
- [ ] Pastikan semua linting warning bersih
