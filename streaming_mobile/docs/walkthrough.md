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
- `MovieModel` dibuat — mapping dari row Supabase ke Dart object
- `HomeRepository` — query paginated dengan filter genre, tahun, dan content_type. Filter genre pakai `ilike` pada JSON string karena kolom disimpan sebagai TEXT bukan JSONB
- `HomeFilterNotifier` + `HomeNotifier` — Riverpod `NotifierProvider` untuk state filter dan daftar konten
- `HomeScreen` — `CustomScrollView` dengan `SliverAppBar` floating, tab Semua/Film/Series, `FilterBar`, grid konten, infinite scroll, pull-to-refresh, dan error view
- `GoRouter` diupdate dengan `ShellRoute` untuk `MainScaffold` + route detail/player placeholder
- `app.dart` direfactor — `ProviderScope` dipindah ke `App` widget, `MaterialApp.router` di `_AppView`

**Keputusan teknis:**
- Filter chaining Supabase harus dilakukan sebelum `.order().range()` — filter tidak bisa dichain setelah `PostgrestTransformBuilder`
- `valueOrNull` tidak tersedia di Riverpod 3.x — diganti `.when(data:, error:, loading:)`
- `MovieModel` tidak perlu export dari barrel features karena dipakai langsung di presentation layer fitur yang sama

---

## Checkpoint 6 — Fitur Detail & Player

---

## Checkpoint 6 — Fitur Detail & Player
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

---

## Checkpoint 7 — Fitur Pencarian & Filter
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

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
