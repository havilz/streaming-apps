# Aturan Pengerjaan Proyek Flutter (Development Rules)

Dokumen ini berisi aturan yang wajib dipatuhi selama pengembangan aplikasi mobile streaming ini agar kode bersih, aman, konsisten, dan mudah dipelihara.

---

## 1. Aturan Keamanan & Kredensial

- **Jangan Komit Kredensial:** Supabase URL, Supabase Anon Key, dan semua data sensitif lainnya wajib disimpan menggunakan `flutter_dotenv` (berkas `.env`) dan tidak boleh dimasukkan ke Git repository. Pastikan `.env` sudah ada di `.gitignore`.
- **Jangan Hardcode Secret:** Semua nilai konfigurasi lingkungan (API key, URL, token) harus dibaca melalui `dotenv.env['KEY']`, bukan ditulis langsung di kode sumber.
- **Supabase RLS (Row Level Security):** Selalu aktifkan RLS pada setiap tabel Supabase. Jangan menonaktifkan RLS dengan alasan kemudahan development.

---

## 2. Aturan Database & Storage (Supabase)

- **Tidak Ada File Video Tersimpan:** Supabase Storage tidak boleh digunakan untuk menyimpan file video mentah (`.mp4`, `.mkv`, dll.). Hanya boleh menyimpan teks berupa URL stream/iframe.
- **Gunakan Tipe Data yang Tepat:** Kolom JSON (seperti `genres`, `seasons`) wajib menggunakan tipe `jsonb` di Supabase, bukan `text`.
- **Naming Convention Tabel:** Nama tabel menggunakan `snake_case`, huruf kecil semua. Contoh: `movies`, `episodes`.

---

## 3. Aturan Arsitektur & Kode

- **Atomic Design Wajib:** Semua komponen UI baru harus ditempatkan pada level yang tepat (atom, molecule, organism, template). Jangan membuat widget kompleks langsung di dalam `presentation/` tanpa memecahnya ke level yang sesuai.
- **Barrel File Wajib:** Setiap folder baru yang dibuat di dalam `lib/` wajib memiliki satu file barrel yang meng-export seluruh isinya. Import antar fitur hanya boleh melalui barrel file, bukan path langsung ke file implementasi.
- **Riverpod untuk State:** Semua state management menggunakan **Riverpod** (`flutter_riverpod`). Dilarang menggunakan `setState` untuk state yang diakses lebih dari satu widget, atau state yang berhubungan dengan data dari Supabase.
- **`ConsumerWidget` untuk UI yang Butuh State:** Widget yang mengkonsumsi provider Riverpod wajib extend `ConsumerWidget` atau `ConsumerStatefulWidget`. Widget murni tanpa state cukup extend `StatelessWidget`.

---

## 4. Aturan UI & Desain

- **Sistem Desain Gelap:** Skema warna wajib mengikuti spesifikasi di [design.md](design.md). Dilarang menggunakan nilai hex atau angka warna secara langsung (*magic number*) di dalam widget. Selalu referensikan token dari `AppColors`.
- **Responsivitas:** Layout harus responsif untuk berbagai ukuran layar Android dan iOS. Gunakan `LayoutBuilder` atau `MediaQuery` jika perlu menyesuaikan layout.
- **Grid Konten:** Grid film/series wajib menggunakan 2 kolom pada layar standar (lebar < 600dp) dan 3 kolom pada layar tablet (lebar ≥ 600dp).
- **No Placeholder Statis:** Gambar poster film harus ditarik dari URL yang tersimpan di Supabase. Gunakan `CachedNetworkImage` dengan shimmer sebagai fallback loading, bukan gambar placeholder statis permanen.
- **Aksesibilitas:** Semua widget interaktif wajib memiliki `Semantics` label yang deskriptif untuk mendukung screen reader.

---

## 5. Aturan Dokumentasi & Progress Tracking

- **Update `task.md` Setiap Selesai Task:** Setiap kali satu item task selesai dikerjakan, status checklist di `task.md` wajib diubah dari `[ ]` menjadi `[x]` sebelum pindah ke task berikutnya.
- **Update `walkthrough.md` Setiap Checkpoint:** Setiap kali satu checkpoint (kelompok task) selesai, wajib mengisi catatan di `walkthrough.md` pada bagian checkpoint yang bersangkutan — termasuk keputusan teknis yang diambil, kendala yang ditemui, dan solusinya.
- **Tidak Boleh Skip:** Dilarang menandai task selesai tanpa benar-benar menyelesaikannya, dan dilarang melewati pembaruan dokumentasi meski task terasa kecil.

---

## 6. Aturan Kualitas Kode

- **Null Safety:** Seluruh kode wajib menggunakan Dart Null Safety penuh. Hindari penggunaan `!` (force unwrap) kecuali benar-benar sudah dipastikan non-null secara logis.
- **Linting:** Ikuti aturan linting dari `analysis_options.yaml` yang sudah dikonfigurasi. Semua warning linter harus diselesaikan, bukan diabaikan.
- **Penamaan:**
  - File: `snake_case.dart`
  - Kelas & Widget: `PascalCase`
  - Variabel, fungsi, parameter: `camelCase`
  - Konstanta: `camelCase` (sesuai konvensi Dart)
- **Komentar:** Setiap kelas publik dan fungsi publik yang tidak trivial wajib memiliki komentar `///` (doc comment) yang menjelaskan tujuannya.
- **Tidak Ada `print()` di Production:** Gunakan logging terstruktur atau hapus semua `print()` sebelum commit ke branch utama.
