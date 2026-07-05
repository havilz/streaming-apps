# Daftar Tugas Pengerjaan (Task List)

Daftar ini digunakan untuk memantau progress pengerjaan proyek. Setiap task yang selesai dikerjakan akan diperbarui statusnya di sini.

---

## Progress Global:
- `[x]` Setup Lingkungan Awal (Next.js & Database)
- `[x]` Implementasi Scraper & Cloudflare Bypass
- `[x]` Pembuatan API Server Internal
- `[x]` Integrasi UI Frontend (Desain Premium)
- `[x]` Pengujian & Finalisasi
- `[ ]` Perbaikan Lanjutan (Feedback v1)

---

## Rincian Langkah Pengerjaan:

### 1. Setup Lingkungan Awal (Next.js & Database)
- [x] Inisialisasi Project Next.js (TypeScript)
- [x] Membuat dokumen perancangan (`design.md`, `project_structure.md`, `rules.md`, `task.md`)
- [x] Install library database SQLite & Prisma (atau library driver sqlite langsung)
- [x] Buat Skema database SQLite untuk menyimpan film, seri, dan episode

### 2. Implementasi Scraper & Cloudflare Bypass
- [x] Buat berkas helper `lib/scraper.ts`
- [x] Terapkan logic bypass gateToken (hitung mundur 15 detik menggunakan persistent header & cookie)
- [x] Uji coba scraper untuk satu film/episode secara backend dan pastikan link video ter-unlock dengan status 200

### 3. Pembuatan API Server Internal
- [x] Buat endpoint sync API `/api/cron/sync` (Opsi B - sinkronisasi berkala)
- [x] Impor hasil sinkronisasi film/seri baru dari target ke database lokal SQLite
- [x] Buat API endpoint `/api/movies` untuk menyajikan list film yang sudah di-cache ke frontend

### 4. Integrasi UI Frontend (Desain Premium)
- [x] Atur style HSL global dan warna merah gelap di `app/globals.css`
- [x] Buat layout global `app/layout.tsx` (Navbar kaca blur, logo teks merah gelap, footer safe)
- [x] Buat halaman utama `app/page.tsx` (Menampilkan slider featured film & grid list film dari database lokal)
- [x] Buat halaman detail pemutar `app/watch/[slug]/page.tsx` (Integrasi Plyr/VideoJS untuk HLS stream, atau sandboxed iframe untuk embed hoster)

### 5. Pengujian & Finalisasi
- [x] Uji coba alur sinkronisasi cron job backend
- [x] Uji coba kelancaran pemutaran video di berbagai resolusi layar
- [x] Buat panduan penyelesaian (`walkthrough.md`)

---

### 6. Perbaikan Lanjutan (Feedback v1)
- [x] **Sinkronisasi Konten Penuh:** Menyesuaikan jumlah film & series di web agar sesuai dengan yang tersedia di idlix (saat ini hanya tersinkronisasi beberapa item saja — perlu pagination/loop sinkronisasi menyeluruh)
- [x] **Perbaikan Error 500 saat Pemutaran:** Investigasi & perbaiki kasus di mana beberapa movie/series mengembalikan HTTP 500 saat tombol play ditekan (kemungkinan terkait episode ID tidak valid, struktur payload yang berbeda, atau token claim gagal)
- [x] **Thumbnail Episode pada Halaman Series:** Tampilkan gambar thumbnail per episode di bagian daftar episode pada halaman detail series, menyesuaikan tampilan seperti yang ada di idlix

---

### 7. Integrasi Multi-Season Series (Feedback v2)
- [x] **Scraper & DB Multi-Season:** Dukungan pengambilan daftar seluruh season dari `/api/series/[slug]` dan penyimpanan season_number yang dinamis pada database SQLite (tabel `episodes`).
- [x] **UI Pilihan Season:** Membuat komponen pemilih season (Season Selector) di halaman detail watch (di bawah daftar episode / di area kategori) untuk beralih antar season secara mulus.

---

### 8. Fitur Filter Navigasi Lanjutan (Feedback v3)
- [x] **Desain Dropdown Filter UI:** Menambahkan deretan dropdown filter horizontal (Genre, Negara, Tahun, dan Network) di halaman utama di bawah capsule tabs.
- [x] **Penyelarasan Kolom Database:** Memastikan kolom pendukung filter (seperti `country`, `release_date`, dan `networks`) tersedia dan terisi di tabel `movies` untuk memproses penyaringan.
- [x] **Logika Query Filter Halaman Utama:** Mengintegrasikan filter terpilih ke dalam parameter kueri SQL di `app/page.tsx` agar daftar film/series tersaring secara akurat.

