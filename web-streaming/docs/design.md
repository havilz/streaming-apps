# Panduan Desain & Sistem Visual (Design System)

Dokumen ini mendefinisikan panduan visual, palet warna, tipografi, komponen UI, dan efek animasi untuk website streaming video kita. Desain ini menggabungkan preferensi warna merah gelap pilihan Anda dengan estetika modern seperti *dark mode* premium, *glassmorphism*, dan mikro-animasi.

---

## 1. Palet Warna (Color Palette)

Untuk memberikan kesan premium (bukan merah polos generik), kita menggunakan warna merah gelap berbasis HSL yang dipadukan dengan latar belakang gelap arang (*dark charcoal*).

| Peran | Nilai Hex / HSL | Representasi Visual |
| :--- | :--- | :--- |
| **Primary Accent (Merah Gelap)** | `#9b1c1c` / `hsl(0, 70%, 36%)` | Warna branding utama, ikon teks, hover border, dll. |
| **Active Background (Merah Gelap Pekat)** | `#7f1d1d` / `hsl(0, 72%, 30%)` | Background link navbar yang aktif. |
| **Dark Red Glow (Glow Effect)** | `rgba(155, 28, 28, 0.4)` | Bayangan bercahaya (*glow shadow*) untuk card dan tombol. |
| **Main Background** | `#0b0f17` / `hsl(220, 35%, 6%)` | Latar belakang website utama. |
| **Elevated Surface (Card/Panel)** | `#111827` / `hsl(220, 30%, 10%)` | Latar belakang card film, dropdown, dan modal. |
| **Text Primary** | `#f9fafb` / `hsl(0, 0%, 98%)` | Warna teks utama (putih pudar). |
| **Text Muted** | `#9ca3af` / `hsl(220, 9%, 65%)` | Teks keterangan, sinopsis, dan meta-info. |

---

## 2. Tipografi (Typography)
Kita akan memuat Google Fonts secara global untuk memberikan kesan elegan dan modern:
*   **Font Header & Logo:** **Outfit** (Sans-serif modern dengan bentuk melingkar geometris yang premium).
*   **Font Body & Konten:** **Inter** (Sangat bersih dan nyaman dibaca untuk teks sinopsis yang panjang).

---

## 3. Komponen Utama & Aturan Layout

### A. Ikon & Logo Website (Brand)
*   **Format:** Berupa teks (Text-only logo), bukan gambar.
*   **Gaya:** Menggunakan font **Outfit** dengan ketebalan *Extra Bold* (800) dan warna merah gelap (`#9b1c1c`).
*   **Efek:** Memiliki transisi lembut saat di-hover dan teks sedikit bercahaya.

### B. Navigasi Bar (Navbar)
*   **Warna Latar:** Semi-transparan dengan efek kaca blur (*Glassmorphism*):
    `background: rgba(11, 15, 23, 0.7); backdrop-filter: blur(12px); border-bottom: 1px solid rgba(255, 255, 255, 0.05);`
*   **Warna Teks:** Putih (`#f9fafb`) untuk semua tautan.
*   **Status Aktif (Active State):**
    *   Teks tetap berwarna putih.
    *   Memiliki latar belakang berwarna merah gelap pekat (`#7f1d1d`).
    *   Bentuk background berupa kapsul (*rounded-full*) dengan padding yang nyaman: `padding: 0.5rem 1rem; border-radius: 9999px;`.
    *   Transisi perubahan background menggunakan animasi transisi yang mulus (`transition: all 0.3s ease`).

### C. Grid & Card Film
*   **Card Design:** Memiliki sudut membulat lebar (`border-radius: 12px`) dan batas tipis transparan.
*   **Hover Effect (Dynamic Design):**
    Saat card film di-hover oleh kursor:
    *   Card akan membesar sedikit (`transform: scale(1.04); transition: transform 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);`).
    *   Muncul bayangan glow merah gelap di belakang card: `box-shadow: 0 10px 20px rgba(155, 28, 28, 0.25);`.
    *   Overlay deskripsi singkat atau tombol putar muncul secara perlahan (*fade-in*).

### D. Pemutar Video (Player Page)
*   Pemutar ditempatkan di tengah layar dengan aspect ratio 16:9 yang lebar.
*   Dikelilingi oleh efek *ambient lighting* (glow merah gelap tipis yang menyebar di latar belakang pemutar video).

---

## 4. Animasi & Efek Transisi
Semua interaksi di dalam website harus terasa hidup dan responsif menggunakan CSS transitions:
*   **Hover Links:** Semua link teks merubah opacity dari `0.7` ke `1` secara instan namun lembut (`transition: opacity 0.2s ease`).
*   **Page Transitions:** Loading bar tipis berwarna merah gelap di bagian atas layar saat berpindah halaman.
