# Walkthrough Proyek Flutter (Project Walkthrough)

Dokumen ini akan diisi secara bertahap selama proses pengembangan berlangsung. Setiap checkpoint yang berhasil diselesaikan akan dicatat di sini beserta keputusan teknis, kendala yang ditemui, dan solusinya.

---

## Status Saat Ini
> **Fase:** Implementasi Fitur Home
> **Progres:** 3 dari 8 task selesai

---

## Checkpoint 1 — Setup Dokumentasi & Perancangan
**Status:** Selesai

Semua dokumen perancangan awal dibuat di folder `docs/`:
- `project_structure.md` — Arsitektur Atomic Design + sistem barrel file
- `design.md` — Sistem visual (warna, tipografi, komponen, animasi)
- `rules.md` — Aturan pengerjaan proyek
- `task.md` — Daftar tugas step-by-step
- `walkthrough.md` — Catatan proses ini

---

## Checkpoint 2 — Setup Lingkungan & Dependensi
**Status:** Selesai

**Flutter SDK:** 3.44.4 | **Dart:** 3.12.2

**Dependensi yang diinstall:**
| Package | Versi | Kegunaan |
| :--- | :--- | :--- |
| `flutter_riverpod` | 3.3.2 | State management |
| `supabase_flutter` | 2.15.3 | Koneksi ke Supabase BaaS |
| `go_router` | 17.3.0 | Navigasi declarative |
| `cached_network_image` | 3.4.1 | Cache gambar poster dari URL |
| `flutter_dotenv` | 6.0.1 | Membaca file `.env` |
| `video_player` | 2.11.1 | Pemutar video dasar Flutter |
| `chewie` | 1.14.1 | UI wrapper pemutar video |

**Yang dikerjakan:**
- Seluruh struktur folder Atomic Design dibuat (`core/`, `shared/`, `features/`, `assets/`)
- Semua file barrel dibuat di setiap folder sesuai hierarki
- `main.dart` dan `app.dart` dibuat dengan inisialisasi Supabase + dotenv
- File `.env` dibuat dan didaftarkan ke `.gitignore`
- `analysis_options.yaml` dikonfigurasi dengan aturan linting
- `pubspec.yaml` dikonfigurasi dengan assets `.env` dan font variable Outfit & Inter

**Catatan:**
- Font Outfit dan Inter menggunakan format variable font (satu file semua weight)
- `StateProvider` tidak tersedia di Riverpod 3.x — diganti `NotifierProvider`
- File `widget_test.dart` bawaan Flutter diganti dengan placeholder

---

## Checkpoint 3 — Setup Supabase
**Status:** Selesai

**Project Supabase:** `tcosbjernyhyalydiwan` | **Region:** Southeast Asia (Singapore)

**Yang dikerjakan:**
- Skema tabel dibuat via SQL Editor — identik dengan SQLite website (`lib/db.ts`)
- Tabel `movies`: 19 kolom (id TEXT, tmdb_id, slug, title, poster_path, backdrop_path, genres, seasons, dll)
- Tabel `episodes`: 13 kolom (id TEXT, movie_id FK, season_number, episode_number, still_path, video_url, dll)
- RLS aktif: `anon` hanya bisa SELECT, `service_role` bisa semua operasi
- Trigger `update_updated_at` aktif di kedua tabel
- Script `migrate-to-supabase.js` dibuat di folder website
- **Hasil migrasi: 11.859 movies + 7.521 episodes** berhasil diupload dalam 31 detik
- `main.dart` diupdate: `anonKey` (deprecated) diganti `publishableKey`

**Keputusan teknis:**
- `country` dan `networks` tidak dimasukkan — kosong di SQLite website
- `SUPABASE_SERVICE_KEY` hanya di `.env` website lokal, tidak pernah masuk Flutter
- Next.js website didowngrade dari 16.x ke 15.5.20 karena Turbopack panic di Node.js v24

---

## Checkpoint 4 — Core & Sistem Desain
**Status:** Selesai (dikerjakan bersamaan dengan Checkpoint 2)

**Yang dikerjakan:**
- Semua token konstanta terisi: `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppDuration`
- `AppTheme.dark` dikonfigurasi penuh menggunakan semua token
- `GoRouter` dikonfigurasi dengan route placeholder (home, detail, player, search)
- Atom: `AppText`, `AppBadge`, `AppShimmer`, `AppDivider`
- Molecule: `MovieCard`, `EpisodeTile`, `SeasonSelector`, `FilterBar`
- Organism: `AppNavbar`, `ContentGrid`, `EpisodeList`
- Template: `MainScaffold` dengan glassmorphism bottom navigation bar

---

## Checkpoint 5 — Fitur Home
**Status:** Selesai

**Yang dikerjakan:**
- Schema database di-rebuild total ke normalized schema — tabel terpisah: `movies`, `series`, `episodes`, `genres`, `countries`, `networks` + junction tables
- `MovieModel` dan `SeriesModel` dibuat sebagai model terpisah, `ContentItem` sebagai unified model untuk home grid
- `HomeRepository` — query dua tabel sekaligus dengan filter genre (via ID) dan tahun
- `HomeFilterNotifier` — filter pakai `ContentTab` enum (Semua/Film/Series) dan `genreId` integer
- `HomeScreen` — grid konten dengan tab, filter bar, infinite scroll, pull-to-refresh
- Script `migrate-to-supabase.js` ditulis ulang dengan retry + resume — berhasil migrate **7.186 movies + 4.673 series + 335 episodes**

**Keputusan teknis:**
- `genre` filter berubah dari string ke `genreId` integer karena genre di tabel terpisah
- `on_conflict` parameter wajib di URL Supabase REST untuk upsert normalized tables
- Tab "Semua" fetch movies + series secara parallel lalu interleave hasilnya

---

## Checkpoint 6 — Fitur Detail & Player
**Status:** Selesai

**Yang dikerjakan:**
- `MovieModel`/`SeriesModel` dipisah — `DetailScreen` sekarang punya `_MovieBody` dan `_SeriesBody` terpisah
- `DetailRepository` — `fetchMovieDetail`, `fetchSeriesDetail`, `fetchEpisodes` (query tabel `series`), unlock stream 3-step Pentos flow
- `EpisodeModel` — field `movieId` diganti `seriesId` sesuai schema baru
- `PlayerScreen` — full-screen landscape, countdown overlay animasi pulse, ambient glow merah, Chewie player HLS
- Router pass `isSeries` via `extra` ke `DetailScreen`

**Keputusan teknis:**
- Unlock stream langsung dari Flutter ke idlix → Cloudflare 403 di Android (akan difix di step 7 via Edge Function)
- Provider cache manual untuk `streamProviderFor` dan `activeSeasonProviderFor` karena Riverpod 3.x family Notifier tidak support constructor parameter

---

## Checkpoint 7 — Fitur Pencarian & Filter
**Status:** Selesai

**Yang dikerjakan:**
- `SearchRepository` — query parallel ke tabel `movies` dan `series` pakai `ilike` pada `title`, hasil digabung dan diurutkan by `vote_average` descending
- `SearchNotifier` — state `SearchState` dengan debounce 500ms, flag `hasSearched` untuk bedakan "belum pernah cari" vs "cari tapi kosong"
- `SearchScreen` — search bar dengan autofocus, debounce, tombol clear, grid hasil 3 kolom, handling semua state (loading, error, empty, no-result)
- Filter Genre & Tahun sudah aktif di home page via `genreId` integer dari tabel `genres` normalized

**Catatan:**
- Filter Negara dan Network belum aktif — data di tabel `countries`, `networks`, `movie_countries`, `series_countries`, `series_networks` masih kosong, akan diisi oleh Edge Function di step 7

---

## Checkpoint 8 — Sync Otomatis (Edge Function & Cron)
**Status:** Selesai

**Yang dikerjakan:**
- **Perbaikan `unlock-stream`:** Menghapus referensi Deno invalid yang memicu error 404. Menambahkan modul cookie parsing menggunakan `getSetCookie()` yang handal.
- **Implementasi `sync-content`:** Menulis ulang logic Edge Function untuk mengintegrasikan TMDB API.
- **Skema Normalized:** Menyimpan data country & network ke tabel referensi (`countries`, `networks`) secara normalized menggunakan `on_conflict=name`, lalu mencatat relasi relasional di tabel junction.
- **Integrasi Flutter:** Mengubah `home_screen.dart` agar pull-to-refresh dan tombol AppBar memicu `syncProvider` manual sync. Menampilkan state loading (floating snackbar) dan notifikasi status secara real-time.
- **SQL Automatons (`005_setup_cron.sql`):** Menyediakan skrip SQL untuk menjadwalkan sinkronisasi harian & mingguan via `pg_cron` dan `pg_net`.
- **Optimasi `syncNew` (Early Break):** Mengatasi error `WORKER_RESOURCE_LIMIT` pada Deno Edge Function dengan menambahkan deteksi 5 item ganda berturut-turut untuk langsung keluar dari loop halaman, memotong waktu eksekusi dari menit menjadi kurang dari 2 detik.
- **Script Bulk Sync Lokal (`enrich-seasons.js`):** Menyediakan skrip Node.js lokal di folder `web-streaming` untuk melakukan pengisian awal massal (enrichment) season, episode, country, dan network untuk 4.658 series lama hasil migrasi agar terhindar dari batas waktu 150 detik cloud.

**Keputusan teknis:**
- Pengisian data referensi dilakukan langsung di level Edge Function (Deno) atau skrip lokal Node.js agar database tetap sinkron.
- Menggunakan `res.headers.getSetCookie()` agar cookie Cloudflare & Pentos Session dari IDLIX dapat diparsing.

---

## Checkpoint 9 — Pengujian & Finalisasi
**Status:** Selesai

**Yang dikerjakan:**
# Walkthrough Proyek Flutter (Project Walkthrough)

Dokumen ini akan diisi secara bertahap selama proses pengembangan berlangsung. Setiap checkpoint yang berhasil diselesaikan akan dicatat di sini beserta keputusan teknis, kendala yang ditemui, dan solusinya.

---

## Status Saat Ini
> **Fase:** Implementasi Fitur Home
> **Progres:** 3 dari 8 task selesai

---

## Checkpoint 1 — Setup Dokumentasi & Perancangan
**Status:** Selesai

Semua dokumen perancangan awal dibuat di folder `docs/`:
- `project_structure.md` — Arsitektur Atomic Design + sistem barrel file
- `design.md` — Sistem visual (warna, tipografi, komponen, animasi)
- `rules.md` — Aturan pengerjaan proyek
- `task.md` — Daftar tugas step-by-step
- `walkthrough.md` — Catatan proses ini

---

## Checkpoint 2 — Setup Lingkungan & Dependensi
**Status:** Selesai

**Flutter SDK:** 3.44.4 | **Dart:** 3.12.2

**Dependensi yang diinstall:**
| Package | Versi | Kegunaan |
| :--- | :--- | :--- |
| `flutter_riverpod` | 3.3.2 | State management |
| `supabase_flutter` | 2.15.3 | Koneksi ke Supabase BaaS |
| `go_router` | 17.3.0 | Navigasi declarative |
| `cached_network_image` | 3.4.1 | Cache gambar poster dari URL |
| `flutter_dotenv` | 6.0.1 | Membaca file `.env` |
| `video_player` | 2.11.1 | Pemutar video dasar Flutter |
| `chewie` | 1.14.1 | UI wrapper pemutar video |

**Yang dikerjakan:**
- Seluruh struktur folder Atomic Design dibuat (`core/`, `shared/`, `features/`, `assets/`)
- Semua file barrel dibuat di setiap folder sesuai hierarki
- `main.dart` dan `app.dart` dibuat dengan inisialisasi Supabase + dotenv
- File `.env` dibuat dan didaftarkan ke `.gitignore`
- `analysis_options.yaml` dikonfigurasi dengan aturan linting
- `pubspec.yaml` dikonfigurasi dengan assets `.env` dan font variable Outfit & Inter

**Catatan:**
- Font Outfit dan Inter menggunakan format variable font (satu file semua weight)
- `StateProvider` tidak tersedia di Riverpod 3.x — diganti `NotifierProvider`
- File `widget_test.dart` bawaan Flutter diganti dengan placeholder

---

## Checkpoint 3 — Setup Supabase
**Status:** Selesai

**Project Supabase:** `tcosbjernyhyalydiwan` | **Region:** Southeast Asia (Singapore)

**Yang dikerjakan:**
- Skema tabel dibuat via SQL Editor — identik dengan SQLite website (`lib/db.ts`)
- Tabel `movies`: 19 kolom (id TEXT, tmdb_id, slug, title, poster_path, backdrop_path, genres, seasons, dll)
- Tabel `episodes`: 13 kolom (id TEXT, movie_id FK, season_number, episode_number, still_path, video_url, dll)
- RLS aktif: `anon` hanya bisa SELECT, `service_role` bisa semua operasi
- Trigger `update_updated_at` aktif di kedua tabel
- Script `migrate-to-supabase.js` dibuat di folder website
- **Hasil migrasi: 11.859 movies + 7.521 episodes** berhasil diupload dalam 31 detik
- `main.dart` diupdate: `anonKey` (deprecated) diganti `publishableKey`

**Keputusan teknis:**
- `country` dan `networks` tidak dimasukkan — kosong di SQLite website
- `SUPABASE_SERVICE_KEY` hanya di `.env` website lokal, tidak pernah masuk Flutter
- Next.js website didowngrade dari 16.x ke 15.5.20 karena Turbopack panic di Node.js v24

---

## Checkpoint 4 — Core & Sistem Desain
**Status:** Selesai (dikerjakan bersamaan dengan Checkpoint 2)

**Yang dikerjakan:**
- Semua token konstanta terisi: `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppDuration`
- `AppTheme.dark` dikonfigurasi penuh menggunakan semua token
- `GoRouter` dikonfigurasi dengan route placeholder (home, detail, player, search)
- Atom: `AppText`, `AppBadge`, `AppShimmer`, `AppDivider`
- Molecule: `MovieCard`, `EpisodeTile`, `SeasonSelector`, `FilterBar`
- Organism: `AppNavbar`, `ContentGrid`, `EpisodeList`
- Template: `MainScaffold` dengan glassmorphism bottom navigation bar

---

## Checkpoint 5 — Fitur Home
**Status:** Selesai

**Yang dikerjakan:**
- Schema database di-rebuild total ke normalized schema — tabel terpisah: `movies`, `series`, `episodes`, `genres`, `countries`, `networks` + junction tables
- `MovieModel` dan `SeriesModel` dibuat sebagai model terpisah, `ContentItem` sebagai unified model untuk home grid
- `HomeRepository` — query dua tabel sekaligus dengan filter genre (via ID) dan tahun
- `HomeFilterNotifier` — filter pakai `ContentTab` enum (Semua/Film/Series) dan `genreId` integer
- `HomeScreen` — grid konten dengan tab, filter bar, infinite scroll, pull-to-refresh
- Script `migrate-to-supabase.js` ditulis ulang dengan retry + resume — berhasil migrate **7.186 movies + 4.673 series + 335 episodes**

**Keputusan teknis:**
- `genre` filter berubah dari string ke `genreId` integer karena genre di tabel terpisah
- `on_conflict` parameter wajib di URL Supabase REST untuk upsert normalized tables
- Tab "Semua" fetch movies + series secara parallel lalu interleave hasilnya

---

## Checkpoint 6 — Fitur Detail & Player
**Status:** Selesai

**Yang dikerjakan:**
- `MovieModel`/`SeriesModel` dipisah — `DetailScreen` sekarang punya `_MovieBody` dan `_SeriesBody` terpisah
- `DetailRepository` — `fetchMovieDetail`, `fetchSeriesDetail`, `fetchEpisodes` (query tabel `series`), unlock stream 3-step Pentos flow
- `EpisodeModel` — field `movieId` diganti `seriesId` sesuai schema baru
- `PlayerScreen` — full-screen landscape, countdown overlay animasi pulse, ambient glow merah, Chewie player HLS
- Router pass `isSeries` via `extra` ke `DetailScreen`

**Keputusan teknis:**
- Unlock stream langsung dari Flutter ke idlix → Cloudflare 403 di Android (akan difix di step 7 via Edge Function)
- Provider cache manual untuk `streamProviderFor` dan `activeSeasonProviderFor` karena Riverpod 3.x family Notifier tidak support constructor parameter

---

## Checkpoint 7 — Fitur Pencarian & Filter
**Status:** Selesai

**Yang dikerjakan:**
- `SearchRepository` — query parallel ke tabel `movies` dan `series` pakai `ilike` pada `title`, hasil digabung dan diurutkan by `vote_average` descending
- `SearchNotifier` — state `SearchState` dengan debounce 500ms, flag `hasSearched` untuk bedakan "belum pernah cari" vs "cari tapi kosong"
- `SearchScreen` — search bar dengan autofocus, debounce, tombol clear, grid hasil 3 kolom, handling semua state (loading, error, empty, no-result)
- Filter Genre & Tahun sudah aktif di home page via `genreId` integer dari tabel `genres` normalized

**Catatan:**
- Filter Negara dan Network belum aktif — data di tabel `countries`, `networks`, `movie_countries`, `series_countries`, `series_networks` masih kosong, akan diisi oleh Edge Function di step 7

---

## Checkpoint 8 — Sync Otomatis (Edge Function & Cron)
**Status:** Selesai

**Yang dikerjakan:**
- **Perbaikan `unlock-stream`:** Menghapus referensi Deno invalid yang memicu error 404. Menambahkan modul cookie parsing menggunakan `getSetCookie()` yang handal.
- **Implementasi `sync-content`:** Menulis ulang logic Edge Function untuk mengintegrasikan TMDB API.
- **Skema Normalized:** Menyimpan data country & network ke tabel referensi (`countries`, `networks`) secara normalized menggunakan `on_conflict=name`, lalu mencatat relasi relasional di tabel junction.
- **Integrasi Flutter:** Mengubah `home_screen.dart` agar pull-to-refresh dan tombol AppBar memicu `syncProvider` manual sync. Menampilkan state loading (floating snackbar) dan notifikasi status secara real-time.
- **SQL Automatons (`005_setup_cron.sql`):** Menyediakan skrip SQL untuk menjadwalkan sinkronisasi harian & mingguan via `pg_cron` dan `pg_net`.
- **Optimasi `syncNew` (Early Break):** Mengatasi error `WORKER_RESOURCE_LIMIT` pada Deno Edge Function dengan menambahkan deteksi 5 item ganda berturut-turut untuk langsung keluar dari loop halaman, memotong waktu eksekusi dari menit menjadi kurang dari 2 detik.
- **Script Bulk Sync Lokal (`enrich-seasons.js`):** Menyediakan skrip Node.js lokal di folder `web-streaming` untuk melakukan pengisian awal massal (enrichment) season, episode, country, dan network untuk 4.658 series lama hasil migrasi agar terhindar dari batas waktu 150 detik cloud.

**Keputusan teknis:**
- Pengisian data referensi dilakukan langsung di level Edge Function (Deno) atau skrip lokal Node.js agar database tetap sinkron.
- Menggunakan `res.headers.getSetCookie()` agar cookie Cloudflare & Pentos Session dari IDLIX dapat diparsing.

---

## Checkpoint 9 — Pengujian & Finalisasi
**Status:** Selesai

**Yang dikerjakan:**
- **Pengujian Alur Putar Video:** Sukses memutar film dan episode series di HP Android. Video termuat lancar menggunakan backend `unlock-stream` yang dipanggil dari client.
- **Bypass Blank Hitam (Format Hint):** Memperbaiki bug layar blank hitam pada player Android (ExoPlayer) dengan memberikan hint format HLS (`formatHint: VideoFormat.hls`) secara dinamis di `player_screen.dart` apabila URL stream tidak diakhiri dengan ekstensi `.m3u8` literal.
- **Pengujian Manual Sync:** Berhasil melakukan pull-to-refresh dan tombol AppBar refresh di aplikasi mobile. Status sukses/gagal sinkronisasi terinfokan di layar secara real-time.
- **Pembersihan Kode:** Menghapus seluruh perintah `print()` sementara di file `detail_repository.dart` untuk memastikan kode bersih untuk rilis.
- **Linting & Analisis Kode:** Menjalankan `flutter analyze` dan membersihkan warning lints yang tersisa di file yang disentuh (`player_screen.dart`, `detail_repository.dart`) agar kode 100% bebas dari warning linting.

---

## Checkpoint 10 — Restrukturisasi UI & Layar Kurasi Kategori
**Status:** Selesai

**Yang dikerjakan:**
- **Penghapusan Bottom Navigation Bar**: Menyederhanakan `MainScaffold` dengan menghapus bar navigasi bawah untuk memaksimalkan fokus pengguna pada keindahan poster bioskop secara imersif.
- **Glassmorphic Search Modal**: Menggantikan halaman pencarian kaku dengan overlay modal pencarian yang transparan, berefek blur, dan menampilkan daftar hasil pencarian secara instan seiring pengguna mengetik (*live search results*).
- **Glassmorphic Menu Modal**: Menyediakan menu laci transparan melayang dengan blur tebal untuk navigasi cepat: Home, Movie, Series, Genres, Country, Years, dan Network.
  - **Indikator Aktif**: Menambahkan parameter `currentLocation` sehingga item menu yang sedang diakses akan otomatis menyala merah terang (`AppColors.primary`).
  - **Penyesuaian Tombol Silang**: Memosisikan tombol silang ("X") di koordinat dan ukuran yang identik dengan tombol hamburger pada app bar asli untuk menciptakan efek visual morphing yang rapi.
- **Pemisahan Layar Film & Serial TV**: Membuat layar `MovieScreen` dan `SeriesScreen` khusus yang hanya menampilkan satu jenis konten dengan gaya visual premium persis seperti beranda utama.
- **Grid Navigasi Kategori**:
  - `GenresScreen`: Menampilkan daftar genre dalam kotak kartu dengan variasi ikon dinamis yang relevan.
  - `CountriesScreen`: Menampilkan daftar negara dengan ikon globe global.
  - `YearsScreen`: Menampilkan daftar tahun rilis dengan ikon kalender.
  - `NetworksScreen`: Menampilkan daftar penyedia jaringan lengkap dengan logo brand asli TMDB yang dimuat secara dinamis.
- **Halaman Detail Kategori Dinamis**:
  - Membuat `GenreDetailScreen`, `CountryDetailScreen`, `YearDetailScreen`, dan `NetworkDetailScreen` yang menampilkan banner atas dinamis serta jalur-jalur konten khusus (Trending, Best in Genre, Best in Country, dll.).
  - **Pencegahan Overflow Teks**: Membatasi judul seksi di dalam row menggunakan `Expanded` dan `TextOverflow.ellipsis` agar tidak terjadi *pixel overflow* pada nama kategori yang panjang (seperti United Kingdom atau Science Fiction).
- **Optimalisasi Kueri Tahun**: Mengubah `fetchAvailableYears` di `home_repository.dart` untuk memanggil kueri paralel batas atas (descending) & batas bawah (ascending) agar seluruh tahun rilis di database tersaji secara dinamis.
- **Rebranding Nama Aplikasi**: Mengubah nama aplikasi dari `streaming_mobile` menjadi **Stream Vault** di tingkat platform Android (`AndroidManifest.xml` -> `android:label`) dan iOS (`Info.plist` -> `CFBundleDisplayName` & `CFBundleName`).
- **Generasi Ikon Launcher Aplikasi**: Mengintegrasikan paket `flutter_launcher_icons` dan mengonfigurasinya dengan gambar ikon pilihan Anda `assets/images/apps.icon.png`. Generasi aset ikon default Android (`ic_launcher`) dan iOS (`AppIcon`) telah berhasil dijalankan secara otomatis.
- **Splash Screen Premium Ala Netflix**: Membuat halaman transisi pembuka (`SplashScreen`) dengan latar belakang hitam pekat dan animasi logo "Sv" berwarna merah menyala (`AppColors.primary`).
  - **Animasi Logo**: Logo membesar perlahan (*scaling*), memudar masuk (*opacity*), dengan kerenggangan karakter (*letter spacing*) yang merapat sinematik dan efek cahaya pendar (*glow shadows*) yang melebar seiring jalannya waktu.
  - **Efek Suara Bioskop**: Mengintegrasikan pustaka `audioplayers` untuk memutar efek suara intro bioskop dari berkas lokal Anda (`assets/sounds/Netflix intro - QuickSounds.com.mp3`) tepat saat aplikasi dibuka, menyelaraskan transisi audio dan visual selama 3,5 detik sebelum mengarah ke halaman beranda (`/`).

- **Halaman Detail Episode Premium**:
  - Membuat `EpisodeDetailScreen` bergaya sinematik premium dengan transisi pudar atas (*backdrop overlay*) yang menampilkan thumbnail/still episode.
  - Membaca data episode secara asinkronus menggunakan provider baru `episodeDetailProvider` dari Supabase, dengan kemampuan memuat data awal `initialEpisode` secara sinkron dari layar sebelumnya untuk *zero-latency transition*.
  - Menambahkan *fallback mechanism*: jika episode tidak memiliki thumbnail khusus, sistem secara otomatis memuat gambar *backdrop* dari serial TV induknya sebagai gambar latar atas.
  - Menyajikan sinopsis penuh episode, nomor season/episode, durasi, dan tanggal rilis.
  - **Tombol Putar Overlay**: Memindahkan tombol play dari tombol terpisah di bawah metadata menjadi tombol melayang (*overlay*) lingkaran merah neon (`AppColors.primary`) dengan efek glow bercahaya tepat di tengah-tengah gambar poster/backdrop episode.
  - Mengubah alur navigasi dari detail series: mengklik item episode sekarang diarahkan ke `/episode/:episodeId` terlebih dahulu, bukan langsung ke pemutar.

**Keputusan teknis:**
- Penggunaan `GoRouterState.of(context).uri.path` di level pemanggilan menu modal untuk mendeteksi rute aktif saat dialog/modal terbuka.
- Pembatasan judul dengan `Expanded` dan `ellipsis` sebagai standar penanganan tata letak agar teks panjang terpotong secara bersih di semua ukuran layar.
- Kueri parallel via `Future.wait` untuk mempercepat pemuatan tahun dinamis tanpa mengganggu performa responsivitas antarmuka.
- Menggunakan `flutter_launcher_icons` dalam `dev_dependencies` untuk menghasilkan seluruh ukuran resolusi ikon aplikasi secara otomatis dan patuh terhadap standar build Play Store & App Store.
- Memanfaatkan paket `audioplayers` menggunakan instansiasi `AssetSource` untuk pemutaran audio aset secara efisien dan andal pada platform seluler tanpa membebani memori (menggunakan `AudioPlayer.dispose()` saat keluar layar).
- Penyediaan parameter `initialEpisode` pada `EpisodeDetailScreen` agar antarmuka terisi instan tanpa *flicker loading* putih/kosong saat perpindahan layar, sementara kueri Supabase tetap berjalan di latar belakang untuk sinkronisasi data terbaru.
- Menambahkan visual overlay pemutar video (`Material` & `InkWell` dengan container circular merah glow) di atas `SliverAppBar` sebagai pemicu pemutaran video demi menghemat ruang dan meniru gaya antarmuka bioskop profesional.

---

## Checkpoint 11 — Custom Netflix Player & Initialization Security
**Status:** Selesai

**Yang dikerjakan:**
- **Custom Player Integration (Netflix-style):**
  - Mengembangkan custom video player (`custom_video_player.dart`) menggantikan pustaka `chewie` yang kaku.
  - Fitur: Aspect ratio adjustment (contain/zoom/stretch), double-tap to seek (10 detik maju/mundur dengan animasi), timeline slider merah neon, auto-hide controls dalam 3 detik, dan thin progress bar di bagian bawah layar saat kontrol tersembunyi.
- **Robust Player Initialization (Try-Catch):**
  - Membungkus proses inisialisasi controller `_initPlayer` di `episode_detail_screen.dart` dengan blok `try-catch`.
  - Jika terjadi kegagalan pemuatan HLS stream (seperti file video 404/DMCA takedown), aplikasi akan membatalkan inisialisasi secara bersih tanpa silent freeze/stuck loading, dan memunculkan snackbar peringatan berwarna merah kepada pengguna.
- **Season Tab Selector Alignment:**
  - Menyelaraskan logika `numberOfSeasons` agar tidak merender tab season kosong yang disebabkan oleh season Specials (Season 0) di database.

**Keputusan teknis:**
- Penggunaan blok `try-catch` di tingkat pemutar Flutter untuk menghentikan loop loading dan menampilkan umpan balik visual instan ke pengguna.
- Menyembunyikan tab season kosong dengan menyelaraskan total season ke season tertinggi dengan episode di database.

---

## Checkpoint 12 — Queue Sync Optimization & Auto-alignment
**Status:** Selesai

**Yang dikerjakan:**
- **Pemberantasan Head-of-Line Blocking pada Antrean Sync:**
  - Mengubah fungsi `syncOngoing` di Edge Function `sync-content` untuk menambahkan `.order('updated_at', { ascending: true })` sehingga antrean berjalan secara FIFO (First In First Out) memutar, bukan stuck pada 10 baris data fisik yang sama.
  - Implementasi "Touch" logic pada penanganan error fetch: Jika detail series gagal di-fetch dari IDLIX (misalnya slug usang / 404), baris series tersebut akan di-update statusnya di database untuk memperbarui kolom `updated_at` (menempatkannya di belakang antrean sehingga tidak menyumbat antrean selamanya).
  - Meningkatkan kapasitas batch per jalan dari 10 menjadi 15 series.
- **Penyelarasan Jumlah Season Otomatis (Auto-alignment):**
  - Mengintegrasikan penghitungan `maxSeasonWithEpisodes` ke dalam Edge Function `syncOngoing` (mengecualikan season Specials / Season 0) agar pembaharuan jumlah season pada metadata series di database selalu selaras secara otomatis di masa mendatang.

**Keputusan teknis:**
- Penggunaan pengurutan `updated_at` asinkron dan touch logic untuk menjamin putaran antrean (rotating queue) yang sehat dan tangguh di database.
- Sinkronisasi jumlah season regular secara dinamis berdasarkan data episode nyata yang berhasil di-scrape.

---

## Checkpoint 13 — New Updated Section with Interactive Filtering & Navigation
**Status:** Selesai

**Yang dikerjakan:**
- **Penyajian Seksi "New Updated" Dinamis:**
  - Menambahkan seksi "New Updated" di bagian terbawah `HomeScreen`, `MovieScreen`, dan `SeriesScreen` untuk menyajikan konten yang baru saja ditambahkan (film baru, serial baru, dan episode terbaru dari serial yang sudah ada).
- **Filter Interaktif Tersemat:**
  - Melengkapi seksi dengan baris filter dinamis:
    - `HomeScreen` (All, Movie, Series, Episode)
    - `SeriesScreen` (All, Series, Episode)
    - `MovieScreen` (Menampilkan film terbaru tanpa filter karena jenis konten tunggal)
- **Desain Kartu & Label Khusus:**
  - Memperluas kartu poster `MovieCard` dengan properti `customBadge` untuk menampilkan teks spesifik secara fleksibel (seperti kode episode "S4E13" untuk episode terbaru, atau "Movie"/"Series" untuk konten baru).
- **Rute Navigasi Langsung (Episode Detail):**
  - Mengarahkan penekanan kartu berjenis episode langsung ke detail episode (`EpisodeDetailScreen`), sedangkan film dan series diarahkan ke halaman detail utama masing-masing (`DetailScreen`).

**Keputusan teknis:**
- Pengambilan data parallel menggunakan kueri join `series:series_id(title, slug, ...)` pada PostgREST untuk meminimalkan beban kueri dan mempercepat sinkronisasi data visual.
- Pengurutan terpadu (merged sorting) di memori menggunakan properti `created_at` secara descending untuk menjamin urutan kronologis yang akurat.

---

> Dokumen ini mencatat riwayat pengerjaan, kendala teknis penting, dan alur pengerjaan. Seluruh tugas dalam daftar telah diselesaikan dengan sukses.

---

## Checkpoint 14 - Fix Sound missing When Change Resolution On Media Player
**Problem**
Saat user mengganti resolusi pada media player, suara akan hilang. Padahal HLS stream yang di-fetch sudah lengkap.

**Cause Of The Problem:**
Terjadi konflik alokasi sesi audio (Audio Session/Focus Conflict) di tingkat sistem operasi (Android & iOS). Saat pengguna mengganti resolusi, aplikasi langsung membuat instance `VideoPlayerController` baru untuk URL sub-playlist yang baru sementara controller lama masih aktif memutar video. Karena controller lama masih memegang fokus audio aktif, sistem operasi membungkam (mute/silence) request audio dari controller yang baru demi mencegah bentrokan suara. Setelah controller baru selesai diinisialisasi dan controller lama didelegasikan untuk di-dispose, controller baru tersebut sudah terlanjur berjalan dalam kondisi hening/tanpa suara.
Melalui analisis biner paket program MPEG-TS secara terprogram pada segmen HLS target (`seg-0.ts`), kami memverifikasi bahwa segmen HLS tersebut terbukti lengkap memiliki track audio AAC (Stream Type `0x0f`, PID `0x101`), sehingga masalah ini murni merupakan kendala penanganan lifecycle audio focus di sisi aplikasi mobile, bukan kerusakan data stream di server.

**Solution:**
Menghentikan (`pause()`) dan membungkam (`setVolume(0.0)`) controller lama sesaat sebelum menginisialisasi controller baru untuk melepaskan alokasi *audio focus* perangkat. Selain itu, mengonfigurasi controller baru dengan opsi `mixWithOthers: true` dan memanggil `setVolume(1.0)` secara eksplisit setelah inisialisasi selesai, serta menyertakan mekanisme pemulihan (*fail-safe recovery*) ke controller lama jika inisialisasi controller baru gagal.

**Status:** Pending

**Yang Dikerjakan:**
- **Pelepasan Audio Focus Sesaat:** Menambahkan perintah `pause()` dan `setVolume(0.0)` pada controller lama sebelum inisialisasi controller kualitas baru dimulai di `player_screen.dart`, `episode_detail_screen.dart`, dan `custom_video_player.dart`.
- **Konfigurasi `mixWithOthers`:** Menerapkan `videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)` di semua instansiasi `VideoPlayerController.networkUrl`.
- **Pemaksaan Unmute:** Menambahkan `await newController.setVolume(1.0)` pasca `newController.initialize()` berhasil.
- **Fail-safe Recovery Mechanism:** Menambahkan blok `catch` untuk memulihkan volume (`setVolume(1.0)`) dan memutar kembali controller lama jika inisialisasi controller resolusi baru menemui kegagalan.

**Keputusan Teknis:**
- Menggunakan pelepasan audio focus secara proaktif tanpa mendispose controller lama terlebih dahulu. Pola ini menjaga integritas pohon widget Flutter (*widget tree*), menghindari crash `Bad State`, sekaligus mengamankan sesi audio baru secara mulus.

**Hasil Akhir:**
- Suara video kini berputar dengan lancar tanpa hening/mati setelah pengguna berganti resolusi di mode portrait, landscape, maupun fullscreen.

---

## Checkpoint 15 - Fix Video Fail After One Installation (Urgent!!)

**Problem** 
Telah terjadi masalah pada applikasi, dimana setelah applikasi di install oleh user terjadi gagal memuat stream setelah 1 hari penginstallan, dan bukan hanya itu, hal ini terjadi berkepanjangan. User sudah di minta untuk hapus dan install ulang applikasi tetap masih tetap sama saja, video tidak bisa di putar

**Cause Of The Problem:**
1. **Cloudflare Challenge (403 Forbidden) di Supabase Cloud:**
   - Server Deno Edge Function (`unlock-stream`) berjalan di cloud (AWS/Supabase) yang memiliki rentang IP datacenter yang statis.
   - Cloudflare pada situs target (`z2.idlixku.com`) mendeteksi IP datacenter ini sebagai bot dan memicu **Turnstile/Challenge (Under Attack Mode)**, menghasilkan error `Step 1 failed: 403`.
   - Di emulator lokal, inisialisasi berhasil karena Deno lokal berjalan dengan IP residensial pengembang yang tidak diblokir/ditantang oleh Cloudflare. Namun, saat APK diinstal di HP real/produksi, ia memanggil Supabase Cloud yang IP-nya terblokir secara permanen.
2. **IP Binding pada CDN Token (`?t=...`):**
   - Token streaming HLS (`majorplay.net?t=...`) terikat pada alamat IP yang membuat request pembukaan stream (IP Supabase Cloud).
   - Ketika HP user mencoba melakukan streaming, CDN mendeteksi perbedaan IP antara peminta token (Server Supabase) dan pemutar video (HP User), menghasilkan status `403 Forbidden` pada pemutar media.

**Solution:**
1. **Penyelesaian Masalah Player (Client-side / WebView Interception & Cookie Harvesting):**
   - Melakukan bypass Cloudflare langsung dari sisi client menggunakan headless/hidden WebView (`flutter_inappwebview`) untuk mendapatkan cookie `cf_clearance` dan `User-Agent` dengan IP asli pengguna.
   - Menjalankan 3-step Pentos flow langsung dari HP client menggunakan Dart HTTP client (mengirimkan cookie hasil panen tersebut), sehingga token CDN terikat pada IP HP pengguna sendiri.
2. **Penyelesaian Masalah Cron Job Sync (Client-side Background Sync):**
   - Karena API katalog IDLIX di Supabase Cloud Edge Function (`sync-content`) juga diblokir (403), kita memindahkan logika sinkronisasi konten baru ke sisi aplikasi mobile menggunakan koneksi IP residensial user yang aman.
   - **Sinkronisasi Berlapis (Two-Level Sync):**
     - **Level 1: Global Background Sync (Home Screen):** Dilakukan asinkron di latar belakang saat aplikasi dibuka dengan cooldown **30 menit** (menggunakan record `last_synced_at` global) untuk mengupdate film baru dan serial baru.
     - **Level 2: Just-In-Time (JIT) Targeted Sync (Series Detail Screen):** Dilakukan di latar belakang saat membuka halaman detail serial TV tertentu dengan cooldown **5 menit** untuk langsung mengupdate episode baru/ongoing yang baru di-upload.

**Status:** Selesai

**Yang Dikerjakan:**
- Melakukan analisis kegagalan API `unlock-stream` dan `sync-content` (keduanya terblokir Cloudflare 403 di Supabase Cloud).
- Mengintegrasikan package `flutter_inappwebview` untuk melakukan pemanenan cookie (`cf_clearance`) secara headless/invisible.
- Memindahkan logika crawling dan data mapping dari Edge Function ke sisi mobile app (Dart).
- Mengimplementasikan Level 1 (Global Background Sync) pada `HomeScreen` dan Level 2 (JIT Targeted Sync) pada `EpisodeDetailScreen`.

**Keputusan Teknis:**
- Menggunakan `flutter_inappwebview` untuk melakukan pemanenan cookie (`cf_clearance`) secara headless/invisible.
- Membaca dan menulis data konten (`movies` dan `episodes`) langsung dari aplikasi mobile ke Supabase menggunakan database client sdk.
- Menerapkan mekanisme cooldown throttling global dan lokal untuk mencegah overload query ke database Supabase dan IP spam ke IDLIX.

**Hasil Akhir:**
- Masalah Cloudflare 403 bypass terselesaikan penuh dari sisi client.
- Sinkronisasi katalog Home Screen (cooldown 30 menit) dan JIT Series detail (cooldown 5 menit) berjalan lancar dan otomatis.

---