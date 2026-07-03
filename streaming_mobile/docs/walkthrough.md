# Walkthrough Proyek Flutter (Project Walkthrough)

Dokumen ini akan diisi secara bertahap selama proses pengembangan berlangsung. Setiap checkpoint yang berhasil diselesaikan akan dicatat di sini beserta keputusan teknis, kendala yang ditemui, dan solusinya.

---

## Status Saat Ini
> **Fase:** Implementasi Fitur Home
> **Progres:** 3 dari 8 task selesai

---

## Checkpoint 1 — Setup Dokumentasi & Perancangan
**Status:** ✅ Selesai

Semua dokumen perancangan awal dibuat di folder `docs/`:
- `project_structure.md` — Arsitektur Atomic Design + sistem barrel file
- `design.md` — Sistem visual (warna, tipografi, komponen, animasi)
- `rules.md` — Aturan pengerjaan proyek
- `task.md` — Daftar tugas step-by-step
- `walkthrough.md` — Catatan proses ini

---

## Checkpoint 2 — Setup Lingkungan & Dependensi
**Status:** ✅ Selesai

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
**Status:** ✅ Selesai

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
**Status:** ✅ Selesai (dikerjakan bersamaan dengan Checkpoint 2)

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
**Status:** ✅ Selesai

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
**Status:** ✅ Selesai

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
**Status:** ✅ Selesai

**Yang dikerjakan:**
- `SearchRepository` — query parallel ke tabel `movies` dan `series` pakai `ilike` pada `title`, hasil digabung dan diurutkan by `vote_average` descending
- `SearchNotifier` — state `SearchState` dengan debounce 500ms, flag `hasSearched` untuk bedakan "belum pernah cari" vs "cari tapi kosong"
- `SearchScreen` — search bar dengan autofocus, debounce, tombol clear, grid hasil 3 kolom, handling semua state (loading, error, empty, no-result)
- Filter Genre & Tahun sudah aktif di home page via `genreId` integer dari tabel `genres` normalized

**Catatan:**
- Filter Negara dan Network belum aktif — data di tabel `countries`, `networks`, `movie_countries`, `series_countries`, `series_networks` masih kosong, akan diisi oleh Edge Function di step 7

---

## Checkpoint 8 — Sync Otomatis (Edge Function + Cron)

---

## Checkpoint 8 — Sync Otomatis (Edge Function + Cron)
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

---

## Checkpoint 9 — Pengujian & Finalisasi
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

---

> Dokumen ini terus diperbarui seiring pengerjaan. Setiap keputusan teknis penting, kendala, atau perubahan dari rencana awal dicatat di sini.
