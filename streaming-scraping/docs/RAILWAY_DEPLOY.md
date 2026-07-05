# 🚀 Panduan Deploy Railway — Stream Vault Bulk Enrichment Worker

## Gambaran Umum

Worker ini akan berjalan **24 jam** di Railway VPS untuk mengisi data yang masih kosong di Supabase:

| Tahap | Target | Sumber Data | Risiko Blokir |
|-------|--------|-------------|---------------|
| **TAHAP 1** | 7.179 Film (overview, backdrop, runtime) | **TMDB API** | ✅ Tidak ada (API resmi) |
| **TAHAP 2** | 974 Series (season & episode) | **IDLIX API** | ⚠️ Mungkin ada (Cloudflare) |

---

## Langkah 1 — Siapkan Repository GitHub

> **Catatan**: File `.env` dan `dev.db` sudah dikecualikan dari `.gitignore`, aman untuk di-push.

1. Buat repository baru di GitHub (bisa Private):
   ```
   https://github.com/new
   ```
   Nama repo: `stream-vault-worker` (atau bebas)

2. Upload seluruh isi folder `c:\project\streaming-project\web-streaming` ke repo tersebut.
   Perintah di PowerShell dari folder `web-streaming`:
   ```powershell
   git init
   git add .
   git commit -m "feat: Railway bulk enrichment worker"
   git remote add origin https://github.com/USERNAME/stream-vault-worker.git
   git push -u origin main
   ```

---

## Langkah 2 — Buat Project di Railway

1. Buka **https://railway.app** dan login.
2. Klik **"New Project"**.
3. Pilih **"Deploy from GitHub repo"** → pilih repo `stream-vault-worker`.
4. Railway akan mendeteksi otomatis bahwa ini adalah project Node.js.

---

## Langkah 3 — Konfigurasi Environment Variables

Di dashboard Railway, masuk ke tab **"Variables"** dan tambahkan variabel berikut:

| Key | Value |
|-----|-------|
| `SUPABASE_URL` | `https://tcosbjernyhyalydiwan.supabase.co` |
| `SUPABASE_SERVICE_KEY` | `eyJhbGciOi...` *(service_role key Anda)* |
| `TMDB_READ_TOKEN` | `eyJhbGciOi...` *(TMDB read token Anda)* |
| `IDLIX_BASE_URL` | `https://z2.idlixku.com` |

> **Penting**: Jangan pernah expose `SUPABASE_SERVICE_KEY` secara publik.

---

## Langkah 4 — Konfigurasi Start Command

Di tab **"Settings"** Railway, ubah:

- **Build Command**: `npm install`
- **Start Command**: `node railway-worker.js`

Atau Railway akan otomatis membaca `Procfile` yang sudah tersedia:
```
worker: node railway-worker.js
```

---

## Langkah 5 — Deploy!

1. Klik **"Deploy"** di Railway.
2. Buka tab **"Logs"** untuk memantau progres secara real-time.
3. Anda akan melihat output seperti ini:

```
╔══════════════════════════════════════════════════════╗
║         STREAM VAULT — BULK ENRICHMENT WORKER        ║
║       Pengisian Data Massal → Supabase Database      ║
╚══════════════════════════════════════════════════════╝

🕐 Dimulai pada: 4/7/2026, 12.00.00

📊 Status Awal:
   - Film belum ter-enrich : 7179 film
   - Series belum lengkap  : 974 series

═══════════════════════════════════════════════════════
🎬 TAHAP 1: Pengisian metadata Film (7179 film)
   Menggunakan TMDB API (aman, tidak ada risiko blokir)
═══════════════════════════════════════════════════════

[MOVIES Ronde 1] — Mulai batch 100 film...
...
```

---

## Estimasi Waktu

| Jenis | Jumlah | Delay/item | Estimasi Selesai |
|-------|--------|------------|------------------|
| Film (TMDB) | 7.179 | 350ms | ~44 menit |
| Series Episodes (IDLIX) | 974 series | ~2-5 menit/series | ~40-80 jam |

> **Catatan**: Waktu series sangat bervariasi tergantung jumlah season dan episode per series.

---

## Pemantauan & Troubleshooting

### Jika Tahap 1 (Film) berhasil tapi Tahap 2 (Series) gagal:
Worker mendeteksi **3x error berturut-turut** dan akan berhenti otomatis dengan pesan:
```
❌ Gagal 3x berturut-turut. Mungkin terblokir Cloudflare.
   Coba jalankan enrich-seasons.js dari komputer lokal Anda.
```
Solusi: Jalankan `node enrich-seasons.js` dari **komputer lokal Anda** (IP rumah tidak diblokir Cloudflare).

### Cek Progress Manual
Anda bisa menjalankan script checker dari lokal kapan saja:
```powershell
node scratch/count_unenriched.js
```

---

## Setelah Worker Selesai

Worker akan berhenti sendiri dengan pesan:
```
╔══════════════════════════════════════════════════════╗
║            ✅ PENGISIAN DATA SELESAI!                 ║
╚══════════════════════════════════════════════════════╝
   Total waktu berjalan: 2j 15m 30d
```

Setelah itu, **Railway tidak perlu berjalan lagi** untuk enrichment masal. Selanjutnya, Supabase Edge Function Anda (`sync-content`) yang akan mengurus pembaruan data harian/mingguan secara otomatis via cron job.
