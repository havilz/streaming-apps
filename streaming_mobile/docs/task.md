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
- `[x]` Implementasi Sync Otomatis (Edge Function + Cron)
- `[x]` Restrukturisasi UI (Penghapusan Bottom Nav, Glass Search/Menu Modal, & Layar Kurasi Kategori)
- `[x]` Pengujian & Finalisasi

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

- [x] Schema normalized sudah dibuat — `countries`, `networks`, `movie_countries`, `series_countries`, `series_networks` sudah ada sebagai tabel terpisah
- [x] Kolom `status` sudah ada di tabel `movies` dan `series`
- [ ] Tambah kolom `status` ke tabel Supabase via SQL Editor:
  ```sql
  ALTER TABLE movies ADD COLUMN IF NOT EXISTS status TEXT;
  ALTER TABLE series ADD COLUMN IF NOT EXISTS status TEXT;
  ```
  > Catatan: cek apakah sudah ada — kalau sudah ada di migration 003 maka skip
- [ ] Data `status`, `country`, `networks` akan diisi oleh Edge Function step 7 saat sync konten baru dari idlix

---

### 7. Implementasi Sync Otomatis (Edge Function + Cron)

> **Arsitektur:**
> - idlix → sumber konten & stream URL
> - TMDB → sumber metadata (overview, status, country, networks, dll)
> - Keduanya disambungkan via `tmdb_id` yang ada di setiap konten idlix

#### 7a. Supabase Edge Function `sync-content`
- [x] Buat Edge Function `sync-content` di Supabase Dashboard → Edge Functions
- [x] Logic utama (port dari `full-sync.js` website, ditulis dalam Deno/TypeScript):
  - Scrape catalog baru dari idlix `/api/movies` dan `/api/series` (pagination)
  - Untuk setiap konten **baru** (belum ada di Supabase):
    - Fetch detail series dari idlix `/api/series/{slug}` → dapat `seasons`
    - Fetch metadata dari TMDB `/movie/{tmdb_id}` atau `/tv/{tmdb_id}` → dapat `overview`, `status`, `country`, `networks`
    - Upsert ke tabel `movies` dengan data lengkap dari awal
  - Upsert episode baru ke tabel `episodes`
- [x] Tambahkan endpoint unlock stream di Edge Function yang sama atau terpisah (`unlock-stream`)
  - Port logika `fetchPlayInfo` dari `lib/scraper.ts` website ke Deno
  - Terima parameter: `episodeId`, `slug`, `isMovie`
  - Return: `{ url, subtitles }` atau error

#### 7b. Supabase Cron
- [x] **Cron Harian** (setiap hari jam 00.00 WIB / 17.00 UTC):
  - Panggil `sync-content` dengan mode `new` — hanya sync konten baru
- [x] **Cron Mingguan** (setiap Senin jam 02.00 WIB / Minggu 19.00 UTC):
  - Panggil `sync-content` dengan mode `ongoing` — update episode untuk series dengan `status = 'Returning Series'` saja
  - Lebih efisien dari sync semua karena hanya proses series yang masih aktif

#### 7c. Integrasi Flutter → Edge Function
- [x] Update `detail_repository.dart` — ganti HTTP request langsung ke idlix dengan panggilan ke Supabase Edge Function `unlock-stream`
  - Ini fix permanen untuk masalah Cloudflare 403 di Android
- [x] Buat `sync_repository.dart` — trigger sync manual via HTTP call ke Edge Function `sync-content`
- [x] Buat `sync_provider.dart` — state loading/success/error saat sync berjalan
- [x] Implementasi **pull-to-refresh** di `HomeScreen` — trigger sync manual
- [x] Implementasi **tombol refresh** di AppBar sebagai alternatif
- [x] Tampilkan snackbar notifikasi hasil sync

---

### 8. Pengujian & Finalisasi
- [x] Uji alur lengkap: buka app → browse konten → buka detail → putar video
- [x] Uji di beberapa ukuran layar (HP kecil, HP besar, tablet) — bypassed (hanya punya 1 HP)
- [x] Uji filter Genre, Tahun, Negara, Network
- [x] Uji pencarian konten
- [x] Uji sync otomatis (cron) dan sync manual (pull-to-refresh + tombol)
- [x] Uji player: countdown unlock, video putar, landscape mode
- [x] Pastikan tidak ada `print()` tersisa di kode
- [x] Buat `walkthrough.md` yang mendokumentasikan seluruh proses dan checkpoint
- [x] Pastikan semua linting warning bersih

---

### 9. Restrukturisasi UI & Layar Kurasi Kategori
- [x] Hapus `BottomNavigationBar` dari `MainScaffold` untuk menyajikan layout bioskop yang lebih bersih dan imersif
- [x] Implementasikan modal overlay pencarian (`SearchModal`) bergaya glassmorphism dengan *live result* saat mengetik
- [x] Implementasikan modal menu (`MenuModal`) dengan efek blur, shortcut navigasi lengkap, penanda aktif (`isActive`) berwarna merah, dan penyesuaian posisi tombol silang ("X")
- [x] Buat layar `MovieScreen` dan `SeriesScreen` khusus yang memisahkan katalog film dan serial TV dengan layout premium ala beranda utama
- [x] Bangun layar grid kategori: `GenresScreen` (kartu ikon genre), `CountriesScreen` (ikon globe), `YearsScreen` (ikon kalender), dan `NetworksScreen` (logo brand dinamis)
- [x] Bangun layar detail dinamis: `GenreDetailScreen`, `CountryDetailScreen`, `YearDetailScreen`, dan `NetworkDetailScreen` lengkap dengan seksi *carousel*, filter interaktif, dan penanganan pemotongan teks judul (*ellipsis*) untuk mencegah *overflow* lebar
- [x] Optimalkan metode `fetchAvailableYears` di `home_repository.dart` menggunakan kueri paralel batas atas (descending) & batas bawah (ascending) untuk menarik seluruh rentang tahun rilis dari database
- [x] Ganti nama user-facing aplikasi menjadi **Stream Vault** di platform Android & iOS
- [x] Pasang dan konfigurasi `flutter_launcher_icons` dengan aset `assets/images/apps.icon.png` untuk memperbarui ikon aplikasi launcher secara otomatis
- [x] Pasang dan konfigurasi paket `audioplayers` untuk pemutaran efek suara MP3 bioskop
- [x] Implementasikan halaman `SplashScreen` dengan animasi logo "Sv" (scaling, opacity, letter spacing, glow shadow) terintegrasi dengan pemutaran efek suara MP3 bioskop selama 3.5 detik, lalu arahkan ke beranda utama
- [x] Implementasikan halaman `EpisodeDetailScreen` bergaya sinematik premium untuk menampilkan sinopsis, detail episode, daftar episode dinamis, serta tombol putar overlay di atas gambar poster
- [x] Integrasi Custom Video Player ala Netflix dari nol (menggantikan pustaka Chewie) dengan fitur aspect ratio, double-tap seek, timeline slider, dan kontrol auto-hide
- [x] Perbaikan inisialisasi video player menggunakan blok `try-catch` untuk menghindari silent crash saat HLS stream gagal dimuat, serta menampilkan pesan error via SnackBar
- [x] Penyelarasan tampilan tab pemilih season di aplikasi mobile agar sinkron dengan data regular season, menghindari tab kosong yang disebabkan oleh season Specials (Season 0)
- [x] Optimasi antrean sinkronisasi (sync-content Edge Function) menggunakan pengurutan `updated_at` ascending untuk mencegah head-of-line blocking (kemacetan antrean akibat series rusak)
- [x] Implementasi anti-blocking "touch" logic pada Edge Function: memperbarui `updated_at` series di database meskipun data IDLIX gagal diambil agar tidak menyumbat antrean
- [x] Implementasi seksi "New Updated" pada beranda utama (`HomeScreen`), halaman film (`MovieScreen`), dan halaman serial TV (`SeriesScreen`) dengan filter interaktif untuk mempermudah verifikasi sinkronisasi konten
- [x] Penambahan pintasan langsung ke rincian episode (`EpisodeDetailScreen`) ketika menekan kartu episode pada seksi "New Updated"

---

### Task 10. Perbaikan Sound menghilang pada saat ganti resolusi video
- [x] Hentikan (pause) dan senyapkan (mute/setVolume 0.0) controller video lama sesaat sebelum menginisialisasi controller baru di `player_screen.dart`, `episode_detail_screen.dart`, dan `custom_video_player.dart`
- [x] Konfigurasi seluruh inisialisasi controller dengan opsi `mixWithOthers: true` pada `VideoPlayerOptions`
- [x] Panggil fungsi `setVolume(1.0)` secara eksplisit segera setelah controller video baru selesai diinisialisasi
- [x] Implementasikan penanganan error (fail-safe recovery) agar jika inisialisasi controller baru gagal, volume controller lama dikembalikan ke `1.0` dan diputar kembali secara otomatis

---

### Task 11. Perbaikan Masalah Gagal Memutar Video setelah 1 hari penginstallan
- [x] Lakukan investigasi penyebab kegagalan stream dengan memanggil Edge Function Supabase Cloud secara terprogram (ditemukan error 403 / Cloudflare Challenge)
- [x] Tambahkan package `flutter_inappwebview: ^6.1.5` ke `pubspec.yaml`
- [x] Buat class `CloudflareBypassService` di client untuk melakukan cookie harvesting (`cf_clearance` & User-Agent) secara headless/tersembunyi
- [x] Refaktor `DetailRepository.unlockStream` untuk menjalankan 3-step Pentos flow secara lokal di Dart dengan cookie hasil panen
- [x] Implementasikan **Global Background Sync** (Level 1) pada saat Home Screen dimuat, lengkap dengan cooldown throttling **30 menit**
- [x] Implementasikan **Just-In-Time (JIT) Targeted Sync** (Level 2) pada saat halaman Detail Series dibuka, lengkap dengan cooldown throttling **5 menit**
- [x] Uji fungsionalitas pemutaran video dan sinkronisasi konten baru di perangkat tanpa local dev backend untuk memastikan 100% bypass berhasil secara live

---

### Task 12. Optimasi Loading Player, Resolusi Buffering, dan Pencegahan Rate Limit 429
- [x] Implementasikan `WebViewSession` pada `cloudflare_bypass.dart` untuk menjaga persistent headless WebView selama Pentos Flow berjalan.
- [x] Refaktor `DetailRepository.unlockStream` menggunakan single `WebViewSession` untuk memotong overhead waktu loading dari ~30s ke ~11s.
- [x] Ganti parsing `HttpClient` di `custom_video_player.dart` dengan `fetchInWebView` untuk mencegah error 403 pada resolusi master.
- [x] Perbaiki logika parsing URL agar mempertahankan parameter token (`?t=...`) untuk URL resolusi anak.
- [x] Integrasikan `httpHeaders` lengkap (`User-Agent` & `Referer`) ke seluruh inisialisasi controller kualitas baru (`VideoPlayerController.networkUrl`).
- [x] Pindahkan logika targeted JIT sync keluar dari method `build` widget anak ke State induk halaman detail untuk mencegah spam request berulang (menghindari error 429).
- [x] Implementasikan pembersihan cache stream provider (`reset()`) di dalam event `dispose()`, `didUpdateWidget()`, dan perpindahan episode guna mencegah URL HLS CDN kedaluwarsa diputar ulang.

---

### Task 13. Restorasi Penanganan Hilang Suara Saat Ganti Resolusi (Checkpoint 14)
- [x] Impor kembali `dart:io` di berkas `custom_video_player.dart`.
- [x] Kembalikan pembuatan virtual master HLS playlist (.m3u8) dengan tag `CODECS="avc1.4d401f,mp4a.40.2"` di `custom_video_player.dart`, `episode_detail_screen.dart`, dan `player_screen.dart`.
- [x] Lewatkan `httpHeaders` berisi browser headers (`User-Agent` & `Referer`) ke dalam instansiasi `VideoPlayerController.file` agar request sub-playlist tidak terblokir 403.
- [x] Lakukan penanganan swap proaktif (pause/mute controller lama, inisialisasi controller baru, pasang volume 1.0, lalu dispose controller lama).
- [x] Tambahkan penanganan *fail-safe recovery* untuk mengaktifkan kembali controller lama jika inisialisasi kualitas baru gagal.
- [x] Jalankan static analysis `flutter analyze` untuk memastikan kode bersih.

---

### Task 14. Hybrid Cloudflare Bypass (Penanganan Turnstile Interaktif)
- [x] Tambahkan import `package:flutter/material.dart` di berkas `cloudflare_bypass.dart` dan `detail_provider.dart`.
- [x] Refaktor `ensureBypass` untuk mencoba bypass headless terlebih dahulu selama 10 detik.
- [x] Implementasikan dialog bottom sheet interaktif `_showVisibleBypassDialog` berisi visible webview jika headless bypass gagal.
- [x] Pastikan dialog bypass menutup sendiri secara otomatis (`auto-dismiss`) setelah cookies/UA berhasil dipanen.
- [x] Perbarui signature method `unlock()` di `detail_provider.dart` agar menerima parameter optional `BuildContext`.
- [x] Integrasikan parameter `context` saat memicu `unlock()` di `player_screen.dart` dan `episode_detail_screen.dart` agar visible challenge dialog dapat ditampilkan.
- [x] Jalankan `flutter analyze` untuk memastikan tidak ada kesalahan sintaks.

---

### Task 15. Resolusi Masalah Suara Hilang & Crash 'VideoPlayerController was used after being disposed' saat Ganti Kualitas
- [x] Simpan referensi provider notifier di `initState()` pada `player_screen.dart` dan `episode_detail_screen.dart` untuk menghindari error `Bad State: using ref in unmounted widget` di Riverpod saat `dispose()`.
- [x] Pindahkan `oldController.dispose()` ke dalam `WidgetsBinding.instance.addPostFrameCallback` agar ditunda sampai frame render selesai, mencegah *used after being disposed* crash saat unmounting widget.
- [x] Bebaskan alokasi `AudioTrack` secara instan dengan memanggil `pause()` dan `setVolume(0.0)` pada old controller sesaat sebelum inisialisasi controller baru.
- [x] Hilangkan gear selector resolusi manual di UI `CustomVideoPlayer` dan serahkan pemutaran ke ABR (Adaptive Bitrate) HLS ExoPlayer bawaan Android agar pergantian resolusi berjalan otomatis di latar belakang tanpa memicu pergantian controller.

---

### Task 16. Perbaikan Supabase JIT Sync Duplikasi Episode & Pembersihan Episode Sampah (Agent Kim Reactivated)
- [x] Tambahkan parameter `onConflict` dengan target `'series_id,season_number,episode_number'` pada operasi `.upsert()` episodes Supabase untuk mencegah crash akibat duplikasi key unik saat ID episode dari IDLIX berubah.
- [x] Implementasikan cleanup step menggunakan query `.not('episode_number', 'in', ...)` untuk menghapus episode usang (sampah) yang ada di database lokal tapi tidak lagi dikembalikan oleh API detail (misal episode 6 s/d 10 pada series *Agent Kim Reactivated*).
- [x] Integrasikan JIT Sync series episode langsung saat halaman detail Series dibuka (`detail_screen.dart`), bukan hanya saat tombol Play ditekan.

---

### Task 17. Penamaan Aplikasi Asli, Pembersihan Prints, & Full Test Suite (Unit/Widget/Integration Tests)
- [x] Kembalikan label aplikasi Android di `AndroidManifest.xml` dari `StreamVaultDebug` ke nama asli **StreamVault**.
- [x] Hapus console print logs tambahan di `cloudflare_bypass.dart` agar log konsol produksi bersih.
- [x] Tambahkan library `integration_test` ke `dev_dependencies` di `pubspec.yaml` dan jalankan `flutter pub get`.
- [x] Buat pengujian unit (`test/unit_test.dart`) untuk memverifikasi fungsionalitas parser VTT Subtitle.
- [x] Buat pengujian widget (`test/widget_test.dart`) untuk memverifikasi UI `ErrorView` dan tombol coba lagi.
- [x] Buat pengujian integrasi (`integration_test/app_test.dart`) untuk memverifikasi startup aplikasi dan loading awal.
- [x] Jalankan seluruh test suite dan pastikan semua pengujian lolos (passed).

---

### Task 18. Implementasi Pull to Sync pada Halaman Detail Konten (Series/Movie/Episode)
- [x] Modifikasi `ClientSyncService` (atau helper pendukung) agar mendukung bypass cooldown (force sync) saat pull-to-refresh manual dipicu oleh pengguna.
- [x] Bungkus layout `CustomScrollView` di `DetailScreen` (`_SeriesBody` dan `_MovieBody`) dengan widget `RefreshIndicator`.
- [x] Implementasikan callback `onRefresh` pada detail Series untuk memicu paksa JIT sync serial/episode dan merefresh UI (invalidate provider).
- [x] Implementasikan callback `onRefresh` pada detail Movie untuk memicu penyegaran detail film.
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

- [x] Schema normalized sudah dibuat — `countries`, `networks`, `movie_countries`, `series_countries`, `series_networks` sudah ada sebagai tabel terpisah
- [x] Kolom `status` sudah ada di tabel `movies` dan `series`
- [ ] Tambah kolom `status` ke tabel Supabase via SQL Editor:
  ```sql
  ALTER TABLE movies ADD COLUMN IF NOT EXISTS status TEXT;
  ALTER TABLE series ADD COLUMN IF NOT EXISTS status TEXT;
  ```
  > Catatan: cek apakah sudah ada — kalau sudah ada di migration 003 maka skip
- [ ] Data `status`, `country`, `networks` akan diisi oleh Edge Function step 7 saat sync konten baru dari idlix

---

### 7. Implementasi Sync Otomatis (Edge Function + Cron)

> **Arsitektur:**
> - idlix → sumber konten & stream URL
> - TMDB → sumber metadata (overview, status, country, networks, dll)
> - Keduanya disambungkan via `tmdb_id` yang ada di setiap konten idlix

#### 7a. Supabase Edge Function `sync-content`
- [x] Buat Edge Function `sync-content` di Supabase Dashboard → Edge Functions
- [x] Logic utama (port dari `full-sync.js` website, ditulis dalam Deno/TypeScript):
  - Scrape catalog baru dari idlix `/api/movies` dan `/api/series` (pagination)
  - Untuk setiap konten **baru** (belum ada di Supabase):
    - Fetch detail series dari idlix `/api/series/{slug}` → dapat `seasons`
    - Fetch metadata dari TMDB `/movie/{tmdb_id}` atau `/tv/{tmdb_id}` → dapat `overview`, `status`, `country`, `networks`
    - Upsert ke tabel `movies` dengan data lengkap dari awal
  - Upsert episode baru ke tabel `episodes`
- [x] Tambahkan endpoint unlock stream di Edge Function yang sama atau terpisah (`unlock-stream`)
  - Port logika `fetchPlayInfo` dari `lib/scraper.ts` website ke Deno
  - Terima parameter: `episodeId`, `slug`, `isMovie`
  - Return: `{ url, subtitles }` atau error

#### 7b. Supabase Cron
- [x] **Cron Harian** (setiap hari jam 00.00 WIB / 17.00 UTC):
  - Panggil `sync-content` dengan mode `new` — hanya sync konten baru
- [x] **Cron Mingguan** (setiap Senin jam 02.00 WIB / Minggu 19.00 UTC):
  - Panggil `sync-content` dengan mode `ongoing` — update episode untuk series dengan `status = 'Returning Series'` saja
  - Lebih efisien dari sync semua karena hanya proses series yang masih aktif

#### 7c. Integrasi Flutter → Edge Function
- [x] Update `detail_repository.dart` — ganti HTTP request langsung ke idlix dengan panggilan ke Supabase Edge Function `unlock-stream`
  - Ini fix permanen untuk masalah Cloudflare 403 di Android
- [x] Buat `sync_repository.dart` — trigger sync manual via HTTP call ke Edge Function `sync-content`
- [x] Buat `sync_provider.dart` — state loading/success/error saat sync berjalan
- [x] Implementasi **pull-to-refresh** di `HomeScreen` — trigger sync manual
- [x] Implementasi **tombol refresh** di AppBar sebagai alternatif
- [x] Tampilkan snackbar notifikasi hasil sync

---

### 8. Pengujian & Finalisasi
- [x] Uji alur lengkap: buka app → browse konten → buka detail → putar video
- [x] Uji di beberapa ukuran layar (HP kecil, HP besar, tablet) — bypassed (hanya punya 1 HP)
- [x] Uji filter Genre, Tahun, Negara, Network
- [x] Uji pencarian konten
- [x] Uji sync otomatis (cron) dan sync manual (pull-to-refresh + tombol)
- [x] Uji player: countdown unlock, video putar, landscape mode
- [x] Pastikan tidak ada `print()` tersisa di kode
- [x] Buat `walkthrough.md` yang mendokumentasikan seluruh proses dan checkpoint
- [x] Pastikan semua linting warning bersih

---

### 9. Restrukturisasi UI & Layar Kurasi Kategori
- [x] Hapus `BottomNavigationBar` dari `MainScaffold` untuk menyajikan layout bioskop yang lebih bersih dan imersif
- [x] Implementasikan modal overlay pencarian (`SearchModal`) bergaya glassmorphism dengan *live result* saat mengetik
- [x] Implementasikan modal menu (`MenuModal`) dengan efek blur, shortcut navigasi lengkap, penanda aktif (`isActive`) berwarna merah, dan penyesuaian posisi tombol silang ("X")
- [x] Buat layar `MovieScreen` dan `SeriesScreen` khusus yang memisahkan katalog film dan serial TV dengan layout premium ala beranda utama
- [x] Bangun layar grid kategori: `GenresScreen` (kartu ikon genre), `CountriesScreen` (ikon globe), `YearsScreen` (ikon kalender), dan `NetworksScreen` (logo brand dinamis)
- [x] Bangun layar detail dinamis: `GenreDetailScreen`, `CountryDetailScreen`, `YearDetailScreen`, dan `NetworkDetailScreen` lengkap dengan seksi *carousel*, filter interaktif, dan penanganan pemotongan teks judul (*ellipsis*) untuk mencegah *overflow* lebar
- [x] Optimalkan metode `fetchAvailableYears` di `home_repository.dart` menggunakan kueri paralel batas atas (descending) & batas bawah (ascending) untuk menarik seluruh rentang tahun rilis dari database
- [x] Ganti nama user-facing aplikasi menjadi **Stream Vault** di platform Android & iOS
- [x] Pasang dan konfigurasi `flutter_launcher_icons` dengan aset `assets/images/apps.icon.png` untuk memperbarui ikon aplikasi launcher secara otomatis
- [x] Pasang dan konfigurasi paket `audioplayers` untuk pemutaran efek suara MP3 bioskop
- [x] Implementasikan halaman `SplashScreen` dengan animasi logo "Sv" (scaling, opacity, letter spacing, glow shadow) terintegrasi dengan pemutaran efek suara MP3 bioskop selama 3.5 detik, lalu arahkan ke beranda utama
- [x] Implementasikan halaman `EpisodeDetailScreen` bergaya sinematik premium untuk menampilkan sinopsis, detail episode, daftar episode dinamis, serta tombol putar overlay di atas gambar poster
- [x] Integrasi Custom Video Player ala Netflix dari nol (menggantikan pustaka Chewie) dengan fitur aspect ratio, double-tap seek, timeline slider, dan kontrol auto-hide
- [x] Perbaikan inisialisasi video player menggunakan blok `try-catch` untuk menghindari silent crash saat HLS stream gagal dimuat, serta menampilkan pesan error via SnackBar
- [x] Penyelarasan tampilan tab pemilih season di aplikasi mobile agar sinkron dengan data regular season, menghindari tab kosong yang disebabkan oleh season Specials (Season 0)
- [x] Optimasi antrean sinkronisasi (sync-content Edge Function) menggunakan pengurutan `updated_at` ascending untuk mencegah head-of-line blocking (kemacetan antrean akibat series rusak)
- [x] Implementasi anti-blocking "touch" logic pada Edge Function: memperbarui `updated_at` series di database meskipun data IDLIX gagal diambil agar tidak menyumbat antrean
- [x] Implementasi seksi "New Updated" pada beranda utama (`HomeScreen`), halaman film (`MovieScreen`), dan halaman serial TV (`SeriesScreen`) dengan filter interaktif untuk mempermudah verifikasi sinkronisasi konten
- [x] Penambahan pintasan langsung ke rincian episode (`EpisodeDetailScreen`) ketika menekan kartu episode pada seksi "New Updated"

---

### Task 10. Perbaikan Sound menghilang pada saat ganti resolusi video
- [x] Hentikan (pause) dan senyapkan (mute/setVolume 0.0) controller video lama sesaat sebelum menginisialisasi controller baru di `player_screen.dart`, `episode_detail_screen.dart`, dan `custom_video_player.dart`
- [x] Konfigurasi seluruh inisialisasi controller dengan opsi `mixWithOthers: true` pada `VideoPlayerOptions`
- [x] Panggil fungsi `setVolume(1.0)` secara eksplisit segera setelah controller video baru selesai diinisialisasi
- [x] Implementasikan penanganan error (fail-safe recovery) agar jika inisialisasi controller baru gagal, volume controller lama dikembalikan ke `1.0` dan diputar kembali secara otomatis

---

### Task 11. Perbaikan Masalah Gagal Memutar Video setelah 1 hari penginstallan
- [x] Lakukan investigasi penyebab kegagalan stream dengan memanggil Edge Function Supabase Cloud secara terprogram (ditemukan error 403 / Cloudflare Challenge)
- [x] Tambahkan package `flutter_inappwebview: ^6.1.5` ke `pubspec.yaml`
- [x] Buat class `CloudflareBypassService` di client untuk melakukan cookie harvesting (`cf_clearance` & User-Agent) secara headless/tersembunyi
- [x] Refaktor `DetailRepository.unlockStream` untuk menjalankan 3-step Pentos flow secara lokal di Dart dengan cookie hasil panen
- [x] Implementasikan **Global Background Sync** (Level 1) pada saat Home Screen dimuat, lengkap dengan cooldown throttling **30 menit**
- [x] Implementasikan **Just-In-Time (JIT) Targeted Sync** (Level 2) pada saat halaman Detail Series dibuka, lengkap dengan cooldown throttling **5 menit**
- [x] Uji fungsionalitas pemutaran video dan sinkronisasi konten baru di perangkat tanpa local dev backend untuk memastikan 100% bypass berhasil secara live

---

### Task 12. Optimasi Loading Player, Resolusi Buffering, dan Pencegahan Rate Limit 429
- [x] Implementasikan `WebViewSession` pada `cloudflare_bypass.dart` untuk menjaga persistent headless WebView selama Pentos Flow berjalan.
- [x] Refaktor `DetailRepository.unlockStream` menggunakan single `WebViewSession` untuk memotong overhead waktu loading dari ~30s ke ~11s.
- [x] Ganti parsing `HttpClient` di `custom_video_player.dart` dengan `fetchInWebView` untuk mencegah error 403 pada resolusi master.
- [x] Perbaiki logika parsing URL agar mempertahankan parameter token (`?t=...`) untuk URL resolusi anak.
- [x] Integrasikan `httpHeaders` lengkap (`User-Agent` & `Referer`) ke seluruh inisialisasi controller kualitas baru (`VideoPlayerController.networkUrl`).
- [x] Pindahkan logika targeted JIT sync keluar dari method `build` widget anak ke State induk halaman detail untuk mencegah spam request berulang (menghindari error 429).
- [x] Implementasikan pembersihan cache stream provider (`reset()`) di dalam event `dispose()`, `didUpdateWidget()`, dan perpindahan episode guna mencegah URL HLS CDN kedaluwarsa diputar ulang.

---

### Task 13. Restorasi Penanganan Hilang Suara Saat Ganti Resolusi (Checkpoint 14)
- [x] Impor kembali `dart:io` di berkas `custom_video_player.dart`.
- [x] Kembalikan pembuatan virtual master HLS playlist (.m3u8) dengan tag `CODECS="avc1.4d401f,mp4a.40.2"` di `custom_video_player.dart`, `episode_detail_screen.dart`, dan `player_screen.dart`.
- [x] Lewatkan `httpHeaders` berisi browser headers (`User-Agent` & `Referer`) ke dalam instansiasi `VideoPlayerController.file` agar request sub-playlist tidak terblokir 403.
- [x] Lakukan penanganan swap proaktif (pause/mute controller lama, inisialisasi controller baru, pasang volume 1.0, lalu dispose controller lama).
- [x] Tambahkan penanganan *fail-safe recovery* untuk mengaktifkan kembali controller lama jika inisialisasi kualitas baru gagal.
- [x] Jalankan static analysis `flutter analyze` untuk memastikan kode bersih.

---

### Task 14. Hybrid Cloudflare Bypass (Penanganan Turnstile Interaktif)
- [x] Tambahkan import `package:flutter/material.dart` di berkas `cloudflare_bypass.dart` dan `detail_provider.dart`.
- [x] Refaktor `ensureBypass` untuk mencoba bypass headless terlebih dahulu selama 10 detik.
- [x] Implementasikan dialog bottom sheet interaktif `_showVisibleBypassDialog` berisi visible webview jika headless bypass gagal.
- [x] Pastikan dialog bypass menutup sendiri secara otomatis (`auto-dismiss`) setelah cookies/UA berhasil dipanen.
- [x] Perbarui signature method `unlock()` di `detail_provider.dart` agar menerima parameter optional `BuildContext`.
- [x] Integrasikan parameter `context` saat memicu `unlock()` di `player_screen.dart` dan `episode_detail_screen.dart` agar visible challenge dialog dapat ditampilkan.
- [x] Jalankan `flutter analyze` untuk memastikan tidak ada kesalahan sintaks.

---

### Task 15. Resolusi Masalah Suara Hilang & Crash 'VideoPlayerController was used after being disposed' saat Ganti Kualitas
- [x] Simpan referensi provider notifier di `initState()` pada `player_screen.dart` dan `episode_detail_screen.dart` untuk menghindari error `Bad State: using ref in unmounted widget` di Riverpod saat `dispose()`.
- [x] Pindahkan `oldController.dispose()` ke dalam `WidgetsBinding.instance.addPostFrameCallback` agar ditunda sampai frame render selesai, mencegah *used after being disposed* crash saat unmounting widget.
- [x] Bebaskan alokasi `AudioTrack` secara instan dengan memanggil `pause()` dan `setVolume(0.0)` pada old controller sesaat sebelum inisialisasi controller baru.
- [x] Hilangkan gear selector resolusi manual di UI `CustomVideoPlayer` dan serahkan pemutaran ke ABR (Adaptive Bitrate) HLS ExoPlayer bawaan Android agar pergantian resolusi berjalan otomatis di latar belakang tanpa memicu pergantian controller.

---

### Task 16. Perbaikan Supabase JIT Sync Duplikasi Episode & Pembersihan Episode Sampah (Agent Kim Reactivated)
- [x] Tambahkan parameter `onConflict` dengan target `'series_id,season_number,episode_number'` pada operasi `.upsert()` episodes Supabase untuk mencegah crash akibat duplikasi key unik saat ID episode dari IDLIX berubah.
- [x] Implementasikan cleanup step menggunakan query `.not('episode_number', 'in', ...)` untuk menghapus episode usang (sampah) yang ada di database lokal tapi tidak lagi dikembalikan oleh API detail (misal episode 6 s/d 10 pada series *Agent Kim Reactivated*).
- [x] Integrasikan JIT Sync series episode langsung saat halaman detail Series dibuka (`detail_screen.dart`), bukan hanya saat tombol Play ditekan.

---

### Task 17. Penamaan Aplikasi Asli, Pembersihan Prints, & Full Test Suite (Unit/Widget/Integration Tests)
- [x] Kembalikan label aplikasi Android di `AndroidManifest.xml` dari `StreamVaultDebug` ke nama asli **StreamVault**.
- [x] Hapus console print logs tambahan di `cloudflare_bypass.dart` agar log konsol produksi bersih.
- [x] Tambahkan library `integration_test` ke `dev_dependencies` di `pubspec.yaml` dan jalankan `flutter pub get`.
- [x] Buat pengujian unit (`test/unit_test.dart`) untuk memverifikasi fungsionalitas parser VTT Subtitle.
- [x] Buat pengujian widget (`test/widget_test.dart`) untuk memverifikasi UI `ErrorView` dan tombol coba lagi.
- [x] Buat pengujian integrasi (`integration_test/app_test.dart`) untuk memverifikasi startup aplikasi dan loading awal.
- [x] Jalankan seluruh test suite dan pastikan semua pengujian lolos (passed).

---

### Task 18. Implementasi Pull to Sync pada Halaman Detail Konten (Series/Movie/Episode)
- [x] Modifikasi `ClientSyncService` (atau helper pendukung) agar mendukung bypass cooldown (force sync) saat pull-to-refresh manual dipicu oleh pengguna.
- [x] Bungkus layout `CustomScrollView` di `DetailScreen` (`_SeriesBody` dan `_MovieBody`) dengan widget `RefreshIndicator`.
- [x] Implementasikan callback `onRefresh` pada detail Series untuk memicu paksa JIT sync serial/episode dan merefresh UI (invalidate provider).
- [x] Implementasikan callback `onRefresh` pada detail Movie untuk memicu penyegaran detail film.
- [x] Bungkus layout `CustomScrollView` di `EpisodeDetailScreen` dengan widget `RefreshIndicator` untuk menyegarkan detail episode aktif.
- [x] Jalankan static analysis dan verifikasi fungsionalitas visual pull-to-refresh di emulator/HP.

---

### Task 19. Optimasi Headless Cloudflare Bypass (Deteksi Tanpa Challenge)
- [x] Modifikasi logika deteksi keberhasilan di `_tryHeadlessBypass` (`cloudflare_bypass.dart`) agar memeriksa jika halaman selesai dimuat tanpa berada di URL deteksi challenge Cloudflare.
- [x] Izinkan penandaan bypass sukses (`hasValidCookies = true`) dan simpan cookies normal meskipun tanpa adanya cookie `cf_clearance`, asalkan URL target berhasil diakses langsung.
- [x] Verifikasi bahwa dialog visual bottom sheet sama sekali tidak muncul (instan play) ketika Cloudflare sedang dalam kondisi mati/tanpa challenge.
- [x] Uji skenario jika Cloudflare sedang aktif memberikan challenge: pastikan fallback dialog visual bottom sheet tetap muncul secara aman dan menutup otomatis setelah Turnstile sukses dicentang.
- [x] Jalankan static analysis dan verifikasi build.

---

### Task 20. Otomatisasi Rilis CI/CD via GitHub Actions
- [x] Buat struktur folder konfigurasi `.github/workflows/`.
- [x] Buat berkas alur kerja `.github/workflows/release.yml` untuk memicu build otomatis pada saat commit/merge di branch `main`.
- [x] Integrasikan mekanisme dynamic tag auto-bumping dengan format `v1.0.0.X` menggunakan bash script.
- [x] Konfigurasi environment variables Supabase URL dan Anon Key untuk diinjeksi ke berkas `.env` dari GitHub Secrets pada saat build.
- [x] Tambahkan langkah kompilasi APK rilis, penyalinan nama ke `StreamVault.apk`, dan pemostingan rilis baru menggunakan `softprops/action-gh-release`.
- [x] Pastikan static analysis bersih di lokal.
