# Panduan Desain & Sistem Visual (Design System)

Dokumen ini mendefinisikan panduan visual, palet warna, tipografi, komponen UI, dan efek animasi untuk aplikasi mobile streaming video ini. Desain sepenuhnya konsisten dengan versi website karena website sudah mendukung tampilan mobile-responsive — sehingga aplikasi ini cukup mengadopsi sistem visual yang sama.

---

## 1. Palet Warna (Color Palette)

Menggunakan warna merah gelap berbasis HSL dipadukan dengan latar belakang gelap arang (*dark charcoal*) untuk kesan premium. Semua nilai ini didefinisikan di `core/constants/app_colors.dart`.

| Peran | Nilai Hex | Keterangan |
| :--- | :--- | :--- |
| **Primary Accent** | `#9b1c1c` | Warna branding utama, aksen tombol, ikon aktif |
| **Active Background** | `#7f1d1d` | Background tab/item navigasi yang sedang aktif |
| **Dark Red Glow** | `rgba(155, 28, 28, 0.4)` | Shadow glow pada card dan tombol |
| **Main Background** | `#0b0f17` | Latar belakang utama seluruh halaman |
| **Elevated Surface** | `#111827` | Latar belakang card, bottom sheet, panel |
| **Text Primary** | `#f9fafb` | Warna teks utama (putih pudar) |
| **Text Muted** | `#9ca3af` | Teks keterangan, sinopsis, meta-info |

---

## 2. Tipografi (Typography)

Didefinisikan di `core/constants/app_typography.dart`. Font dimuat via `pubspec.yaml` dari folder `assets/fonts/`.

- **Header & Logo:** **Outfit** — Sans-serif geometris modern, digunakan untuk judul, nama aplikasi, dan heading section.
- **Body & Konten:** **Inter** — Bersih dan nyaman untuk sinopsis panjang, label, dan metadata.

### Skala Ukuran Teks

| Token | Ukuran | Penggunaan |
| :--- | :--- | :--- |
| `textXs` | 11sp | Label badge, caption kecil |
| `textSm` | 13sp | Meta info, keterangan sekunder |
| `textMd` | 15sp | Body teks, deskripsi sinopsis |
| `textLg` | 18sp | Sub-heading, judul card |
| `textXl` | 22sp | Heading section |
| `text2xl` | 28sp | Judul halaman, nama film |

---

## 3. Komponen Utama & Aturan Layout

### A. Logo & Branding Aplikasi
- Berupa teks saja (text-only logo), tanpa gambar raster.
- Font **Outfit**, ketebalan `FontWeight.w800`, warna `#9b1c1c`.
- Digunakan di AppBar halaman utama.

### B. Navigasi Bawah (Bottom Navigation Bar)
- Latar belakang semi-transparan dengan efek *glassmorphism*:
  - `color: Color(0xCC0b0f17)` (background utama + opacity 80%)
  - `blur: 12px` via `BackdropFilter`
  - Border atas tipis: `Color(0x0Dffffff)` (putih 5%)
- **State Aktif:** Ikon & label berwarna `#9b1c1c`, background kapsul `#7f1d1d`.
- **State Nonaktif:** Ikon & label berwarna `#9ca3af`.
- Transisi perubahan state menggunakan `AnimatedContainer` dengan durasi 250ms.

### C. Card Konten Film/Series (`MovieCard`)
- Sudut membulat: `BorderRadius.circular(12)`
- Background surface: `#111827`
- Border tipis transparan: `Border.all(color: Color(0x1Affffff))`
- **Efek Hover/Press (InkWell + GestureDetector):**
  - Scale sedikit membesar via `AnimatedScale` atau `Transform.scale`.
  - Shadow glow merah gelap muncul: `BoxShadow(color: Color(0x66_9b1c1c), blurRadius: 20)`.
  - Overlay info fade-in di bagian bawah card.
- Rasio aspek poster: **2:3** (standar poster film).

### D. Halaman Detail & Pemutar Video
- **Detail Screen:** Banner/backdrop film di bagian atas dengan gradient fade ke bawah menuju background gelap.
- **Player Screen:** Pemutar video full-screen dengan aspect ratio 16:9.
  - Efek *ambient lighting*: glow merah gelap tipis di belakang area video.
  - **Loading Countdown Screen:** Animasi 15 detik saat proses bypass stream berlangsung, menampilkan tahapan proses secara visual (sama seperti website).
- **Episode List:** Thumbnail gambar per episode (`still_path`), dilengkapi badge nomor episode dan tanggal tayang.

### E. Filter Bar
- Deretan `DropdownButton` atau `ChoiceChip` horizontal untuk Genre dan Tahun.
- Bisa di-scroll secara horizontal jika opsi melebihi lebar layar.
- Warna aktif menggunakan `#9b1c1c`, nonaktif `#111827`.

### F. Season Selector
- Baris tombol season yang dapat di-scroll secara horizontal.
- Tombol aktif: background `#9b1c1c`, teks putih.
- Tombol nonaktif: background `#111827`, teks `#9ca3af`.

---

## 4. Spacing & Sizing

Didefinisikan di `core/constants/app_spacing.dart` dan `core/constants/app_radius.dart`.

| Token | Nilai | Penggunaan |
| :--- | :--- | :--- |
| `spaceXs` | 4dp | Gap antar ikon & label |
| `spaceSm` | 8dp | Padding dalam badge, jarak kecil |
| `spaceMd` | 16dp | Padding horizontal halaman (standar) |
| `spaceLg` | 24dp | Jarak antar section |
| `spaceXl` | 32dp | Padding vertikal besar |
| `radiusSm` | 6dp | Border radius badge |
| `radiusMd` | 12dp | Border radius card |
| `radiusLg` | 20dp | Border radius bottom sheet |
| `radiusFull` | 9999dp | Border radius kapsul (pill) |

---

## 5. Animasi & Efek Transisi

Durasi didefinisikan di `core/constants/app_duration.dart`.

| Token | Durasi | Kurva | Penggunaan |
| :--- | :--- | :--- | :--- |
| `durationFast` | 150ms | `easeOut` | Feedback tap, opacity cepat |
| `durationNormal` | 250ms | `easeInOut` | Transisi state navigasi, hover card |
| `durationSlow` | 400ms | `easeInOut` | Page transition, modal masuk/keluar |

- **Page Transition:** Transisi antar halaman menggunakan slide dari kanan (default `GoRouter`) dengan durasi `durationSlow`.
- **Shimmer Loading:** Efek shimmer saat data sedang dimuat dari Supabase, menggunakan `app_shimmer.dart`.
- **Card Press:** `InkWell` dengan splash color `Color(0x1A9b1c1c)` (merah gelap transparan).
