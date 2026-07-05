# Struktur Proyek (Project Structure)

Berikut adalah struktur folder dan berkas untuk website streaming Next.js ini, beserta deskripsi fungsinya masing-masing:

```text
web-streaming/
├── app/                        # Direktori utama Next.js (App Router)
│   ├── api/                    # Endpoint API backend
│   │   ├── cron/
│   │   │   └── sync/
│   │   │       └── route.ts    # API Scraper sinkronisasi terjadwal (Opsi B)
│   │   └── movies/
│   │       └── route.ts        # API internal untuk menyajikan data film dari DB ke Frontend
│   ├── watch/
│   │   └── [slug]/
│   │       └── page.tsx        # Halaman detail film dan pemutar video (Player)
│   ├── favicon.ico
│   ├── globals.css             # Style global (Tailwind v4 & variabel HSL desain)
│   ├── layout.tsx              # Wrapper layout utama (Navbar, Footer, Outfit & Inter fonts)
│   └── page.tsx                # Halaman utama (Homepage) berisi grid list film
├── docs/                       # Dokumentasi pengerjaan proyek
│   ├── design.md               # Spesifikasi visual, warna, dan animasi
│   ├── project_structure.md    # Struktur folder dan file proyek (berkas ini)
│   ├── rules.md                # Aturan pengerjaan proyek
│   └── task.md                 # Daftar tugas & checklist pengerjaan
├── lib/                        # Helper & utilitas proyek
│   ├── db.ts                   # Koneksi ke database SQLite
│   └── scraper.ts              # Logika scraping (impersonasi TLS got-scraping, delay 15s)
├── public/                     # Aset statis (gambar, logo, ikon)
├── .env                        # Variabel lingkungan (API keys, target domain, secret token)
├── .gitignore
├── eslint.config.mjs
├── next.config.ts
├── package.json
└── tsconfig.json
```

---

## Deskripsi Folder Tambahan

1. **`lib/`**:
   * **`db.ts`**: Menginisialisasi koneksi database SQLite (`dev.db`). Jika menggunakan ORM seperti Prisma, file client database akan di-export dari sini.
   * **`scraper.ts`**: Kumpulan fungsi untuk menembak API target. Berisi logika untuk melakukan request Langkah 1, menunggu 15 detik secara asinkron, mengirim `gateToken` di Langkah 2 dengan sidik jari user-agent/cookie yang sama, dan mengembalikan URL video ter-unlock.

2. **`app/api/cron/sync/`**:
   * API Route ini akan bertindak sebagai *trigger* cron job. Ketika dipanggil, API ini akan mengambil daftar film terbaru dari homepage target, memeriksa apakah ada film baru, melakukan proses unlock video di backend, dan menyimpannya ke SQLite database.
