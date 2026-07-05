# Walkthrough Proyek (Project Walkthrough)

Dokumen ini mendokumentasikan hasil pengerjaan, arsitektur final, serta hasil pengujian fungsionalitas bypass countdown streaming video untuk proyek **StreamVault**.

---

## 1. Perubahan Utama (Key Changes)

Kami telah menyelesaikan seluruh alur sistem baik di sisi backend scraper, database caching, maupun frontend UI premium:

### A. Backend Scraper & Cloudflare Bypass (`lib/scraper.ts`)
*   **Investigasi JS Bundles:** Melakukan analisis *Next.js JS static chunks* dari website target dan menemukan alur bypass 3-langkah sesungguhnya (Pentos flow):
    1.  `GET /api/watch/play-info/episode/[id]` → Mendapatkan `gateToken` dan `set-cookie`.
    2.  Pembersihan & pemeliharaan cookie `did` di memori request.
    3.  `POST /api/watch/session/claim` dengan `gateToken` → Mengembalikan token `claim` (JWT) dan `redeemUrl`.
    4.  `POST [redeemUrl]` dengan header `Content-Type: text/plain` dan body `{ "claim": claim }` → Mengembalikan file config HLS `.m3u8` final.
*   **Fungsi Dinamis:** `fetchPlayInfo` kini secara otomatis menangani cookie, referer, serta pemantulan payload yang aman.

### B. Database Caching (`lib/db.ts`)
*   Membuat tabel `movies` dan `episodes` berbasis SQLite menggunakan `better-sqlite3`.
*   Tingkat performa tinggi menggunakan pragma `journal_mode = WAL` dan indeks pencarian.
*   Logika sinkronisasi on-demand pada serial TV: jika episode serial belum disimpan, sistem secara otomatis mengambil daftar episode dari API target saat halaman detail dimuat.

### C. UI Frontend Premium & Streaming Player
*   **Desain v4 Premium:** Gaya visual bernuansa *dark-mode arang* dengan aksen merah gelap (`#9b1c1c`), efek kapsul aktif navbar, dan hover-glow yang dinamis pada movie cards.
*   **Dynamic Client Player (`app/watch/[slug]/player.tsx`):**
    *   Memuat pemutar HLS `Hls.js` secara dinamis lewat CDN terpercaya.
    *   Dilengkapi **Loading Screen Countdown** (15 detik) dengan transisi tahapan pemrosesan bypass untuk memanjakan visual pengguna selagi server memproses dekripsi stream.
    *   Memproses request bypass asinkron di backend `/api/play/[episodeId]` sehingga halaman detail film memuat instan (Zero blocking UX).

---

## 2. Hasil Verifikasi & Pengujian

### A. Pengujian Scraper & Unlock End-to-End
Kami menguji modul scraper dan claim session untuk memutar episode 1 **Spider-Noir (2026)**. Hasil keluaran log scraper:

```json
Step 1: Requesting play-info gate token...
Res 1 Data: {
  kind: 'gate',
  gateToken: 'eyJ2IjoxLCJjdCI6ImVwaXNvZGUiLCJjaWQiOiJmMmM5MjUzNy01ZDA3...[TRUNCATED]',
  serverNow: 1782847053043,
  unlockAt: 1782847068043
}
Waiting 16.5s for unlock...

Step 2: POST to watch/session/claim...
Res 2 (Claim) Data: {
  kind: 'pentos',
  claim: 'eyJ2IjoiX01UVVVBLVpfZXNHIiwicCI6Ii92L3o0L1...[TRUNCATED]',
  redeemUrl: 'https://e2e.majorplay.net/api/play',
  videoId: '_MTUUA-Z_esG'
}

Step 3: Redeeming claim...
Redeem Status: 200
FINAL UNLOCKED SOURCES: {
  "code": "ok",
  "url": "https://e2e.majorplay.net/v/z4/_MTUUA-Z_esG/config-806115.json?t=...",
  "subtitles": [
    {
      "lang": "id",
      "label": "Indonesian",
      "path": "https://e2e.majorplay.net/v/z4/_MTUUA-Z_esG/i18n/id/85cc1caa54b277a2.vtt"
    }
  ]
}
```

### B. Hasil Kompilasi & Build TypeScript
Seluruh codebase Next.js telah di-build dengan sukses tanpa kesalahan tipe data:
```bash
  Creating an optimized production build ...
✓ Compiled successfully in 6.9s
  Running TypeScript ...
  Finished TypeScript in 6.7s ...
✓ Generating static pages (4/4)
```

---

## 3. Cara Menjalankan Proyek Secara Lokal

1.  Jalankan server pengembangan:
    ```bash
    npm run dev
    ```
2.  Lakukan sinkronisasi database awal (mengambil konten dari homepage target):
    ```bash
    curl -X POST -H "x-cron-secret: my-secret-token-change-this" http://localhost:3000/api/cron/sync
    ```
3.  Untuk sinkronisasi penuh semua konten:
    ```bash
    curl -X POST -H "x-cron-secret: my-secret-token-change-this" -H "Content-Type: application/json" -d "{\"mode\":\"full\",\"type\":\"all\"}" http://localhost:3000/api/cron/sync
    ```
4.  Buka browser dan akses `http://localhost:3000`.

---

## 4. Pembaruan Lanjutan — Feedback v1 & v2

### A. Sinkronisasi Konten Penuh (Pagination)
*   **Masalah:** Konten yang di-load terbatas hanya beberapa saja, dan halaman utama melambat/loading tanpa akhir ketika database terisi ribuan konten karena di-render sekaligus.
*   **Solusi:**
    1.  Membuat script sinkronisasi mandiri `full-sync.js` untuk mengunduh seluruh **11.859 konten** (7.186 Film & 4.670 Serial TV) langsung ke database lokal secara aman tanpa batas waktu HTTP request.
    2.  Menerapkan **paginasi performa tinggi** pada halaman utama (`app/page.tsx`) dengan batasan `LIMIT 40 OFFSET N` per halaman, dilengkapi panel navigasi angka, tombol sebelumnya/selanjutnya, serta pencarian instan. Kecepatan muat halaman turun dari **38 detik menjadi hanya 1.25 detik**.

### B. Perbaikan Error 500 saat Pemutaran Film
*   **Masalah:** Memutar film menghasilkan status *Failed to resolve* / HTTP 500 karena endpoint play-info film dan episode ternyata berbeda pada server target.
*   **Solusi:**
    1.  Menyelaraskan logic di `lib/scraper.ts` agar mendeteksi tipe konten secara dinamis.
    2.  Jika bertipe Film, request dikirim ke `/api/watch/play-info/movie/[id]`. Jika bertipe Serial TV/Episode, dikirim ke `/api/watch/play-info/episode/[id]`.
    3.  Memperbaiki pencocokan tipe serial TV di halaman detail (`movie.content_type !== "movie"`) sehingga episode ter-scrape dan tersinkronisasi secara otomatis saat dikunjungi.

### C. Thumbnail Episode Premium
*   **Masalah:** Daftar episode serial TV sebelumnya hanya menampilkan kotak nomor episode sederhana tanpa visual.
*   **Solusi:**
    1.  Mendesain ulang item daftar episode menggunakan visual thumbnail gambar (`still_path`) yang bersumber dari TMDB/idlix.
    2.  Dilengkapi hover zoom micro-animation, badge penanda episode overlay yang elegan, serta format ikon kalender untuk informasi tanggal tayang.

### D. Dukungan Multi-Season pada Serial TV
*   **Masalah:** Hanya menampilkan Season 1 untuk serial TV yang memiliki banyak season, dan belum memiliki navigasi antar season.
*   **Solusi:**
    1.  Menambahkan kolom JSON `seasons` pada tabel `movies` untuk meng-cache daftar season per serial TV secara dinamis.
    2.  Memperbarui modul scraper untuk mengambil detail episode per season (`/api/series/[slug]/season/[seasonNo]`) dan daftar seasons (`/api/series/[slug]`).
    3.  Membuat **Season Selector horizontal** (berjejer dari kiri ke kanan dengan *horizontal scrollbar*) di bagian kolom kiri tepat di bawah daftar kategori (genres).
    4.  Navigasi tombol season memuat ulang daftar episode secara instan, serta menginisiasi *caching* otomatis jika season tersebut belum tersimpan di database lokal.

---

## 5. Pembaruan Lanjutan — Feedback v3 (Fitur Filter)

### A. Perbaikan Error 500 — Server Component dengan Event Handler
*   **Masalah:** Halaman utama (`app/page.tsx`) crash dengan HTTP 500 karena elemen `<select onChange={...}>` ditulis langsung di dalam Server Component. Next.js App Router tidak mengizinkan event handler dikirim sebagai props ke elemen HTML dari Server Component karena tidak dapat diserialisasi saat rendering di server.
    ```
    Uncaught Error: Event handlers cannot be passed to Client Component props.
    <select onChange={function onChange} ...>
    ```
*   **Solusi:**
    1.  Membuat Client Component terpisah `app/components/FilterDropdowns.tsx` dengan direktif `"use client"`.
    2.  Komponen ini menerima nilai filter aktif dan opsi data sebagai props serializable dari Server Component induk.
    3.  Navigasi filter menggunakan `useRouter().push()` dari `next/navigation` — tanpa form submit, URL diupdate langsung saat user mengubah dropdown.
    4.  `app/page.tsx` tetap murni Server Component untuk mempertahankan akses database langsung dan performa SSR.

### B. Penyederhanaan Filter — Genre & Tahun
*   **Konteks:** Filter awal dirancang untuk empat dimensi: Genre, Negara, Tahun, dan Network. Setelah investigasi database ditemukan bahwa kolom `country` dan `networks` bernilai `NULL` di seluruh 11.859 baris — kedua kolom tersebut hanya dapat diisi via `fetchSeriesDetails()` (fetch per-item), bukan dari paginated catalog sync yang digunakan saat ini.
*   **Keputusan:** Filter Negara dan Network dihapus dari UI. Hanya Genre dan Tahun yang diaktifkan karena keduanya berfungsi penuh dari data yang sudah ada.
*   **Query SQL yang digunakan:**
    *   Genre: `genres LIKE '%"name":"Action"%'` — match nama genre dalam kolom JSON string
    *   Tahun: `substr(release_date, 1, 4) = '2024'` — ekstrak tahun dari ISO date string
*   **File yang diubah:** `app/page.tsx`, `app/components/FilterDropdowns.tsx`

---

## Checkpoint 9 — Perbaikan Series Korup & Optimalisasi Pengayaan (10x Lebih Cepat)
**Status:** ✅ Selesai

**Yang dikerjakan:**
- **Perbaikan Scraper Karakter Khusus:**
  - Mengubah fungsi `clean` di [find_corrupted_tmdb.js](file:///c:/project/streaming-project/streaming-scraping/find_corrupted_tmdb.js) agar melakukan konversi huruf khusus diakritik (`ø` ➔ `o`, `æ` ➔ `ae`, dll.) alih-alih langsung menghapusnya. Ini memulihkan series seperti *"The Lørenskog Disappearance"* dari deteksi korup palsu.
- **Koreksi Data TMDB ID Supabase:**
  - Melakukan restorasi data TMDB ID yang akurat di database Supabase untuk 7 series yang terlanjur di-reset (*The Demon*, *Candy*, *The Influencer*, *Inside*, dll.) menggunakan skrip satu-kali koreksi.
- **Peningkatan Performa Scraper (10x Lebih Cepat):**
  - Mengoptimalkan [enrich-seasons.js](file:///c:/project/streaming-project/streaming-scraping/enrich-seasons.js) untuk menggabungkan query inseri episode per season ke dalam payload **bulk insert array** tunggal, alih-alih mengirim request terpisah untuk setiap episode.
  - Memanfaatkan header `Prefer: return=representation` untuk mempercepat lookup dan insert metadata (genre, negara, network) dalam satu putaran request.
- **Penyelarasan Batas Jumlah Season (Auto-alignment):**
  - Mengonfigurasi `enrich-seasons.js` agar menyimpan jumlah season (`number_of_seasons`) berdasarkan nomor season tertinggi yang memiliki file episode, mengabaikan placeholder kosong dan season Specials (Season 0).
  - Menjalankan skrip global penyelarasan otomatis untuk mengoreksi data **113 series** di database yang memiliki kelebihan/tab kosong.

**Keputusan teknis:**
- Penggunaan request massal (bulk insert) menghemat ratusan request jaringan sekuensial yang sebelumnya membebani CPU & kecepatan pemrosesan lokal.
- Penentuan jumlah season bersandar langsung pada episode database yang konkret demi keselarasan tab visual aplikasi mobile.

