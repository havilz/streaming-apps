# Walkthrough Proyek Flutter (Project Walkthrough)

Dokumen ini akan diisi secara bertahap selama proses pengembangan berlangsung. Setiap checkpoint yang berhasil diselesaikan akan dicatat di sini beserta keputusan teknis, kendala yang ditemui, dan solusinya.

---

## Status Saat Ini
> **Fase:** Perancangan & Dokumentasi Awal
> **Tanggal Mulai:** *(akan diisi saat implementasi dimulai)*

---

## Checkpoint 1 — Setup Dokumentasi & Perancangan
**Status:** ✅ Selesai

Semua dokumen perancangan awal telah dibuat di folder `docs/`:
- `project_structure.md` — Arsitektur folder Atomic Design + sistem barrel file
- `design.md` — Sistem visual (warna, tipografi, komponen, animasi)
- `rules.md` — Aturan pengerjaan proyek
- `task.md` — Daftar tugas step-by-step
- `walkthrough.md` — Catatan proses ini

Desain visual dan logika bisnis sepenuhnya mengacu pada website StreamVault yang sudah berjalan, dengan adaptasi untuk Flutter (native mobile, bukan web view).

---

## Checkpoint 2 — Setup Lingkungan & Dependensi
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

Hal yang akan dicatat:
- Versi Flutter SDK yang digunakan
- Daftar dependensi final di `pubspec.yaml`
- Kendala setup (jika ada)

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
- Semua folder struktur Atomic Design dibuat (`core/`, `shared/`, `features/`, `assets/`)
- Seluruh konstanta sistem desain dibuat: `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppDuration`
- `AppTheme.dark` dikonfigurasi penuh menggunakan semua konstanta
- Semua file barrel dibuat di setiap folder sesuai hierarki yang dirancang
- Seluruh atom dibuat: `AppText`, `AppBadge`, `AppShimmer`, `AppDivider`
- Seluruh molecule dibuat: `MovieCard`, `EpisodeTile`, `SeasonSelector`, `FilterBar`
- Seluruh organism dibuat: `AppNavbar`, `ContentGrid`, `EpisodeList`
- Template `MainScaffold` dibuat
- `main.dart` dan `app.dart` dibuat dengan inisialisasi Supabase + dotenv
- File `.env` dibuat dan didaftarkan ke `.gitignore`
- `analysis_options.yaml` dikonfigurasi dengan aturan linting proyek
- `pubspec.yaml` dikonfigurasi dengan assets `.env` dan deklarasi font Outfit & Inter

**Catatan penting:**
- Font Outfit dan Inter belum ada di `assets/fonts/` — file `.ttf` harus diunduh manual dari Google Fonts dan diletakkan di folder tersebut sebelum build pertama
- Peringatan symlink Developer Mode di Windows tidak menghalangi development, hanya untuk build production Android
- Semua stub screen (`HomeScreen`, `DetailScreen`, `PlayerScreen`, `SearchScreen`) sudah tersedia dengan implementasi placeholder — akan diisi pada task selanjutnya

---

## Checkpoint 3 — Setup Supabase
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

Hal yang akan dicatat:
- Nama project Supabase & region yang dipilih
- Skema tabel final (jika ada perubahan dari rancangan di `task.md`)
- Hasil verifikasi migrasi data dari SQLite
- Hasil uji koneksi Flutter ↔ Supabase

---

## Checkpoint 4 — Core & Sistem Desain
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

Hal yang akan dicatat:
- Keputusan teknis pada `ThemeData`
- Cara implementasi efek glassmorphism di Flutter (karena berbeda dari CSS)
- Hasil render atom-atom dasar

---

## Checkpoint 5 — Fitur Home
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

---

## Checkpoint 6 — Fitur Detail & Player
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

Hal yang akan dicatat:
- Cara implementasi loading countdown 15 detik di Flutter
- Library video player yang dipilih dan alasannya
- Cara panggil backend unlock stream (Edge Function / endpoint website)

---

## Checkpoint 7 — Fitur Pencarian & Filter
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

---

## Checkpoint 8 — Pengujian & Finalisasi
**Status:** ⏳ Belum dimulai

*(Akan diisi setelah langkah ini selesai)*

---

> Dokumen ini akan terus diperbarui seiring pengerjaan. Setiap kali ada keputusan teknis penting, kendala tak terduga, atau perubahan dari rencana awal — catat di sini agar mudah dilacak kembali.
