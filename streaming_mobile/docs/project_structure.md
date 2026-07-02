# Struktur Proyek Flutter (Project Structure)

Proyek ini menggunakan pola **Atomic Design** dengan sistem **barrel file** untuk mempermudah import. Semua konstanta, tema, dan komponen dapat diimpor hanya dari satu titik tanpa harus melacak path satu per satu.

---

## Struktur Folder

```text
streaming_mobile/
├── lib/
│   ├── main.dart                        # Entry point aplikasi
│   │
│   ├── core/                            # Fondasi lintas fitur (non-UI)
│   │   ├── constants/
│   │   │   ├── app_colors.dart          # Semua warna (merah gelap, background, surface, dll.)
│   │   │   ├── app_typography.dart      # Font family, ukuran teks, font weight
│   │   │   ├── app_spacing.dart         # Nilai padding, margin, gap (xs, sm, md, lg, xl)
│   │   │   ├── app_radius.dart          # Nilai border radius (sm, md, lg, full)
│   │   │   ├── app_duration.dart        # Durasi animasi (fast, normal, slow)
│   │   │   └── constants.dart           # BARREL: export semua file di folder constants/
│   │   │
│   │   ├── theme/
│   │   │   ├── app_theme.dart           # ThemeData Flutter utama (dark theme)
│   │   │   └── theme.dart               # BARREL: export semua file di folder theme/
│   │   │
│   │   ├── router/
│   │   │   ├── app_router.dart          # Konfigurasi routing (GoRouter)
│   │   │   └── router.dart              # BARREL: export semua file di folder router/
│   │   │
│   │   ├── network/
│   │   │   ├── supabase_client.dart     # Inisialisasi & singleton Supabase client
│   │   │   ├── api_endpoints.dart       # Daftar konstanta nama tabel & Edge Function
│   │   │   └── network.dart             # BARREL: export semua file di folder network/
│   │   │
│   │   ├── utils/
│   │   │   ├── extensions.dart          # Extension methods (String, DateTime, dll.)
│   │   │   ├── formatters.dart          # Fungsi format (durasi, tanggal, angka)
│   │   │   └── utils.dart               # BARREL: export semua file di folder utils/
│   │   │
│   │   └── core.dart                    # BARREL UTAMA: export semua sub-barrel di core/
│   │
│   ├── features/                        # Fitur-fitur aplikasi (dibagi per domain)
│   │   │
│   │   ├── home/                        # Fitur Halaman Utama
│   │   │   ├── data/
│   │   │   │   ├── home_repository.dart # Ambil data film/series dari Supabase
│   │   │   │   └── data.dart            # BARREL
│   │   │   ├── domain/
│   │   │   │   ├── home_provider.dart   # Riverpod provider untuk state home
│   │   │   │   └── domain.dart          # BARREL
│   │   │   ├── presentation/
│   │   │   │   ├── home_screen.dart     # Halaman utama (grid konten + filter)
│   │   │   │   └── presentation.dart    # BARREL
│   │   │   └── home.dart                # BARREL FITUR: export semua layer home
│   │   │
│   │   ├── detail/                      # Fitur Halaman Detail & Player
│   │   │   ├── data/
│   │   │   │   ├── detail_repository.dart
│   │   │   │   └── data.dart
│   │   │   ├── domain/
│   │   │   │   ├── detail_provider.dart
│   │   │   │   └── domain.dart
│   │   │   ├── presentation/
│   │   │   │   ├── detail_screen.dart   # Halaman detail film/series
│   │   │   │   ├── player_screen.dart   # Halaman pemutar video penuh
│   │   │   │   └── presentation.dart
│   │   │   └── detail.dart
│   │   │
│   │   ├── search/                      # Fitur Pencarian
│   │   │   ├── data/
│   │   │   │   ├── search_repository.dart
│   │   │   │   └── data.dart
│   │   │   ├── domain/
│   │   │   │   ├── search_provider.dart
│   │   │   │   └── domain.dart
│   │   │   ├── presentation/
│   │   │   │   ├── search_screen.dart
│   │   │   │   └── presentation.dart
│   │   │   └── search.dart
│   │   │
│   │   └── features.dart                # BARREL GLOBAL: export semua barrel fitur
│   │
│   ├── shared/                          # Komponen UI yang digunakan lintas fitur
│   │   │
│   │   ├── atoms/                       # Elemen paling dasar (tidak punya dependensi UI lain)
│   │   │   ├── app_text.dart            # Widget teks dengan style terapan
│   │   │   ├── app_badge.dart           # Badge genre/label kecil
│   │   │   ├── app_shimmer.dart         # Efek loading shimmer
│   │   │   ├── app_divider.dart         # Garis pemisah bertema
│   │   │   └── atoms.dart               # BARREL
│   │   │
│   │   ├── molecules/                   # Kombinasi beberapa atom
│   │   │   ├── movie_card.dart          # Card film (poster + judul + hover glow)
│   │   │   ├── episode_tile.dart        # Item episode (thumbnail + info)
│   │   │   ├── season_selector.dart     # Pemilih season horizontal
│   │   │   ├── filter_bar.dart          # Baris filter (Genre, Tahun)
│   │   │   └── molecules.dart           # BARREL
│   │   │
│   │   ├── organisms/                   # Kombinasi molecules yang membentuk seksi UI besar
│   │   │   ├── content_grid.dart        # Grid konten film/series
│   │   │   ├── episode_list.dart        # Daftar episode lengkap
│   │   │   ├── app_navbar.dart          # Bottom navigation bar aplikasi
│   │   │   └── organisms.dart           # BARREL
│   │   │
│   │   ├── templates/                   # Layout/scaffold halaman (tanpa data nyata)
│   │   │   ├── main_scaffold.dart       # Scaffold utama dengan navbar
│   │   │   └── templates.dart           # BARREL
│   │   │
│   │   └── shared.dart                  # BARREL GLOBAL: export atoms, molecules, organisms, templates
│   │
│   └── app.dart                         # Root widget MaterialApp + ProviderScope
│
├── assets/
│   ├── fonts/                           # Font Outfit & Inter
│   └── images/                          # Aset gambar lokal (logo, placeholder)
│
├── docs/                                # Dokumentasi proyek
│   ├── design.md
│   ├── project_structure.md             # (File ini)
│   ├── rules.md
│   ├── task.md
│   └── walkthrough.md
│
├── pubspec.yaml                         # Dependensi & konfigurasi Flutter
└── analysis_options.yaml                # Aturan linter Dart
```

---

## Sistem Barrel File

Setiap folder memiliki satu file barrel (nama folder + `.dart`) yang meng-export seluruh isinya. Contoh pemakaian:

```dart
// ❌ Cara lama — import satu per satu
import 'package:streaming_mobile/core/constants/app_colors.dart';
import 'package:streaming_mobile/core/constants/app_spacing.dart';
import 'package:streaming_mobile/shared/atoms/app_text.dart';

// ✅ Cara dengan barrel — satu baris untuk semua
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/shared/shared.dart';
```

---

## Hierarki Barrel

```
core.dart
  └── constants/constants.dart  → app_colors, app_typography, app_spacing, app_radius, app_duration
  └── theme/theme.dart          → app_theme
  └── router/router.dart        → app_router
  └── network/network.dart      → supabase_client, api_endpoints
  └── utils/utils.dart          → extensions, formatters

shared.dart
  └── atoms/atoms.dart          → app_text, app_badge, app_shimmer, app_divider
  └── molecules/molecules.dart  → movie_card, episode_tile, season_selector, filter_bar
  └── organisms/organisms.dart  → content_grid, episode_list, app_navbar
  └── templates/templates.dart  → main_scaffold

features.dart
  └── home/home.dart            → data, domain, presentation
  └── detail/detail.dart        → data, domain, presentation
  └── search/search.dart        → data, domain, presentation
```

---

## Deskripsi Layer Per Fitur

Setiap fitur mengikuti pola 3 layer:

| Layer | Tanggung Jawab |
| :--- | :--- |
| **`data/`** | Komunikasi langsung dengan Supabase (query tabel, panggil Edge Function). Mengembalikan model data mentah. |
| **`domain/`** | Riverpod `Provider` / `AsyncNotifier`. Mengelola state, mengorkestrasi repository, dan mengekspos data ke UI. |
| **`presentation/`** | Widget Flutter (`ConsumerWidget`). Hanya bertanggung jawab merender UI berdasarkan state dari domain. |
