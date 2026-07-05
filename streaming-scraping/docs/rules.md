# Aturan Pengerjaan Proyek (Development Rules)

Dokumen ini berisi sekumpulan aturan ketat yang wajib dipatuhi selama proses pengembangan website streaming ini agar kode bersih, aman, dan bekerja secara efisien.

---

## 1. Aturan Keamanan & Kredensial (.env)
*   **Jangan Komit Kredensial:** Domain target API, token API, dan data sensitif lainnya wajib disimpan di berkas `.env` dan tidak boleh dimasukkan ke Git repository.
*   Gunakan variabel `.env` di sisi server saja. Jangan berikan awalan `NEXT_PUBLIC_` untuk URL API target agar domain target tidak bocor ke browser client/pengunjung.

---

## 2. Aturan Database & Storage
*   **Dilarang Mengunduh Video:** Database SQLite (`dev.db`) hanya boleh menyimpan tautan teks (*stream URL* atau *iframe URL*). Proyek ini tidak boleh menyimpan file video mentah (`.mp4`, dll.) di disk server lokal guna menghemat kapasitas penyimpanan dan bandwidth.
*   **Pembersihan Otomatis (Optional):** Link video yang sudah kadaluarsa (jika ada token berdurasi di dalamnya) harus diperbarui secara otomatis lewat scraper saat pengunjung meminta pemutaran ulang jika status link kadaluarsa.

---

## 3. Aturan Scraping & API Bypass
*   **Konsistensi Session (Critical):** Semua request scraping ke API target harus menggunakan fungsi dari `lib/scraper.ts`. Sidik jari HTTP (User-Agent, headers, cookie) harus disimpan secara persisten di antara Langkah 1 (gate token request) dan Langkah 2 (unlock request) agar server target tidak mendeteksi sebagai bot baru dan mereset countdown 15 detik.
*   **Gunakan Delay yang Aman:** Selalu berikan toleransi waktu tunggu minimal `1.5` detik lebih lama dari waktu `unlockAt` yang diberikan oleh API target untuk menghindari kegagalan sinkronisasi akibat perbedaan milidetik pada jam server.

---

## 4. Aturan UI & Desain (CSS/Tailwind)
*   **Sistem Desain Gelap:** Skema warna wajib mengikuti spesifikasi di [design.md](file:///c:/project/web-streaming/docs/design.md).
*   **Responsivitas:** Layout halaman utama (grid film) wajib menggunakan CSS Grid yang responsif (layar mobile 2 kolom, tablet 4 kolom, desktop 6 kolom).
*   **No Placeholders:** Semua aset gambar poster film harus ditarik langsung dari tautan TMDB yang ada pada respons API homepage target. Jangan gunakan gambar placeholder statis untuk konten film asli.
*   **Interaktivitas Pemutar:** Pemutar video di halaman detail harus dilindungi dari iklan popup eksternal (sandboxed iframe jika menggunakan embed link, atau direct video player jika menggunakan HLS).
