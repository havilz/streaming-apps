/**
 * railway-worker.js
 * ==========================================
 * Main worker untuk Railway VPS.
 * Menjalankan proses pengisian data massal (bulk enrichment) secara terus-menerus
 * hingga semua data di Supabase yang masih kosong berhasil terisi, lalu berhenti.
 *
 * Urutan proses:
 *   1. Enrich Movies → mengambil detail film (overview, backdrop, tagline, runtime) dari TMDB
 *   2. Enrich Series Episodes → mengambil data season & episode dari IDLIX
 *
 * Jalankan: node railway-worker.js
 */

import path from 'path';
import { fileURLToPath } from 'url';
import { readFileSync, existsSync } from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// --- Load .env (jika ada, untuk pengujian lokal) ---
const envPath = path.join(__dirname, '.env');
if (existsSync(envPath)) {
  try {
    const envContent = readFileSync(envPath, 'utf8');
    for (const line of envContent.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const [key, ...rest] = trimmed.split('=');
      if (key && !process.env[key.trim()]) {
        process.env[key.trim()] = rest.join('=').trim();
      }
    }
  } catch {
    // Abaikan error, Railway sudah punya env vars sendiri
  }
}

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;

// --- Konfigurasi Notifikasi via ntfy.sh (opsional, GRATIS, 0 signup) ---
// 1. Install app 'ntfy' di HP (Play Store / App Store)
// 2. Subscribe ke topic unik Anda di app ntfy
// 3. Isi NTFY_TOPIC di Railway Variables dengan nama topic yang sama
const NTFY_TOPIC = process.env.NTFY_TOPIC ?? '';  // contoh: 'streamvault-namaku-2024'

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('❌ SUPABASE_URL dan SUPABASE_SERVICE_KEY wajib diisi sebagai environment variable.');
  process.exit(1);
}

// --- Konfigurasi Worker ---
const BATCH_SIZE      = 100;   // Jumlah konten per iterasi (per batch)
const DELAY_BETWEEN_ROUNDS_MS = 5000; // Jeda 5 detik antar-iterasi sebelum mulai lagi

// --- Supabase REST Helper ---
async function getCountRemaining() {
  // Hitung total yang masih perlu di-enrich
  const [moviesRes, seriesEpsRes] = await Promise.all([
    fetch(`${SUPABASE_URL}/rest/v1/movies?overview=is.null&select=id`, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Prefer': 'count=exact',
      },
    }),
    // Series dengan 0 episode diperiksa via filter di memory setelah fetch daftar episodes count
    fetch(`${SUPABASE_URL}/rest/v1/series?or=(status.is.null,number_of_seasons.is.null)&select=id`, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Prefer': 'count=exact',
      },
    }),
  ]);

  const parseCount = (res) => {
    const range = res.headers.get('content-range');
    if (range) return parseInt(range.split('/')[1], 10) || 0;
    return 0;
  };

  return {
    movies: parseCount(moviesRes),
    seriesMetadata: parseCount(seriesEpsRes),
  };
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

// --- Kirim notifikasi push via ntfy.sh ---
async function sendNotification(title, message, isError = false) {
  if (!NTFY_TOPIC) return; // Lewati jika tidak dikonfigurasi
  try {
    await fetch(`https://ntfy.sh/${NTFY_TOPIC}`, {
      method: 'POST',
      headers: {
        'Title':    title,
        'Priority': isError ? 'urgent' : 'default',
        'Tags':     isError ? 'x,rotating_light' : 'white_check_mark,clapper',
        'Content-Type': 'text/plain',
      },
      body: message,
    });
    console.log('🔔 Notifikasi push berhasil dikirim!');
  } catch (err) {
    console.warn(`⚠️  Gagal kirim notifikasi: ${err.message}`);
  }
}

// --- Format waktu ---
function now() {
  return new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });
}

function formatDuration(ms) {
  const totalSeconds = Math.floor(ms / 1000);
  const hours   = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  return `${hours}j ${minutes}m ${seconds}d`;
}

// =============================================
// MAIN WORKER LOOP
// =============================================
async function runWorker() {
  console.log('');
  console.log('╔══════════════════════════════════════════════════════╗');
  console.log('║         STREAM VAULT — BULK ENRICHMENT WORKER        ║');
  console.log('║       Pengisian Data Massal → Supabase Database      ║');
  console.log('╚══════════════════════════════════════════════════════╝');
  console.log('');
  console.log(`🕐 Dimulai pada: ${now()}`);
  console.log('');

  const startTime = Date.now();
  const { default: { spawn } } = await import('child_process');

  // ==========================================
  // TAHAP 0: BERSIHKAN DATA TMDB YANG KORUP (via find_corrupted_tmdb.js)
  // ==========================================
  console.log('═══════════════════════════════════════════════════════');
  console.log(`🧹 TAHAP 0: Pemeriksaan dan Pembersihan Data TMDB Korup`);
  console.log('═══════════════════════════════════════════════════════');
  console.log('');

  try {
    await new Promise((resolve, reject) => {
      const child = spawn(
        process.execPath,
        ['find_corrupted_tmdb.js'],
        {
          cwd: __dirname,
          stdio: 'inherit',
          env: process.env,
        }
      );
      child.on('close', (code) => {
        if (code === 0 || code === null) resolve();
        else reject(new Error(`find_corrupted_tmdb.js exited with code ${code}`));
      });
      child.on('error', reject);
    });
    console.log('\n✓ TAHAP 0 Selesai.');
  } catch (err) {
    console.warn(`⚠️  Gagal menjalankan pembersihan korupsi TMDB: ${err.message}`);
  }
  console.log('');

  // --- Cek status setelah pembersihan ---
  const initial = await getCountRemaining();
  console.log('📊 Status Pekerjaan:');
  console.log(`   - Film belum ter-enrich : ${initial.movies} film`);
  console.log(`   - Series belum lengkap  : ${initial.seriesMetadata} series`);
  console.log('');

  if (initial.movies === 0 && initial.seriesMetadata === 0) {
    console.log('🎉 Semua data sudah lengkap! Worker masuk ke mode siaga.');
    console.log(`   Total waktu: ${formatDuration(Date.now() - startTime)}`);
    console.log('💤 Pekerjaan selesai. Menghindari restart Railway dengan tidur selamanya...');
    setInterval(() => {
      console.log(`[IDLE] Worker dalam mode siaga - ${now()}`);
    }, 1000 * 60 * 60 * 12);
    return;
  }

  // ==========================================
  // TAHAP 1: ENRICH MOVIES (via TMDB API)
  // ==========================================
  if (initial.movies > 0) {
    console.log('═══════════════════════════════════════════════════════');
    console.log(`🎬 TAHAP 1: Pengisian metadata Film (${initial.movies} film)`);
    console.log('   Menggunakan TMDB API (aman, tidak ada risiko blokir)');
    console.log('═══════════════════════════════════════════════════════');
    console.log('');

    let totalMoviesProcessed = 0;
    let movieRound = 0;

    while (true) {
      movieRound++;
      console.log(`[MOVIES Ronde ${movieRound}] ${now()} — Mulai batch ${BATCH_SIZE} film...`);

      await new Promise((resolve, reject) => {
        const child = spawn(
          process.execPath,
          ['enrich-details.js', '--type', 'movies', '--limit', String(BATCH_SIZE), '--delay', '350'],
          {
            cwd: __dirname,
            stdio: 'inherit',
            env: process.env,
          }
        );
        child.on('close', (code) => {
          if (code === 0 || code === null) resolve();
          else reject(new Error(`enrich-details.js exited with code ${code}`));
        });
        child.on('error', reject);
      });

      const remaining = await getCountRemaining();
      totalMoviesProcessed = initial.movies - remaining.movies;
      console.log(`\n   ✓ Sisa film: ${remaining.movies} | Progress: ${totalMoviesProcessed}/${initial.movies} (${((totalMoviesProcessed/initial.movies)*100).toFixed(1)}%)`);
      console.log('');

      if (remaining.movies === 0) {
        console.log('🎉 Semua film berhasil ter-enrich!');
        console.log('');
        break;
      }

      console.log(`   ⏳ Jeda ${DELAY_BETWEEN_ROUNDS_MS / 1000} detik sebelum batch berikutnya...`);
      await sleep(DELAY_BETWEEN_ROUNDS_MS);
    }
  } else {
    console.log('✅ TAHAP 1 dilewati — semua film sudah ter-enrich.');
    console.log('');
  }

  // ==========================================
  // TAHAP 2: ENRICH SERIES SEASONS & EPISODES (via IDLIX API)
  // ==========================================
  if (initial.seriesMetadata > 0) {
    console.log('═══════════════════════════════════════════════════════');
    console.log(`📺 TAHAP 2: Pengisian Season & Episode Series`);
    console.log('   Menggunakan IDLIX API (mungkin ada risiko 403 Cloudflare di VPS)');
    console.log('═══════════════════════════════════════════════════════');
    console.log('');

    let seriesRound = 0;
    let consecutiveFail = 0;

    while (true) {
      seriesRound++;
      console.log(`[SERIES Ronde ${seriesRound}] ${now()} — Mulai pengisian series...`);

      let exitCode = 0;
      await new Promise((resolve) => {
        const child = spawn(
          process.execPath,
          ['enrich-seasons.js'],
          {
            cwd: __dirname,
            stdio: 'inherit',
            env: process.env,
          }
        );
        child.on('close', (code) => {
          exitCode = code ?? 0;
          resolve();
        });
        child.on('error', () => { exitCode = 1; resolve(); });
      });

      const remaining = await getCountRemaining();
      console.log(`\n   ✓ Sisa series: ${remaining.seriesMetadata}`);
      console.log('');

      if (remaining.seriesMetadata === 0) {
        console.log('🎉 Semua series berhasil ter-enrich!');
        break;
      }

      if (exitCode !== 0) {
        consecutiveFail++;
        console.warn(`⚠️  Gagal ${consecutiveFail}x berturut-turut (mungkin terblokir Cloudflare).`);
        if (consecutiveFail >= 3) {
          console.error('❌ Gagal 3x berturut-turut. Menghentikan pengisian series sementara.');
          console.error('   Coba jalankan enrich-seasons.js dari komputer lokal Anda.');
          break;
        }
        const backoff = 60_000 * consecutiveFail;
        console.log(`   ⏳ Menunggu ${backoff / 1000} detik sebelum mencoba lagi...`);
        await sleep(backoff);
      } else {
        consecutiveFail = 0;
        console.log(`   ⏳ Jeda ${DELAY_BETWEEN_ROUNDS_MS / 1000} detik sebelum ronde berikutnya...`);
        await sleep(DELAY_BETWEEN_ROUNDS_MS);
      }
    }
  } else {
    console.log('✅ TAHAP 2 dilewati — semua series sudah ter-enrich.');
    console.log('');
  }

  // ==========================================
  // SELESAI
  // ==========================================
  const elapsed = Date.now() - startTime;
  const summary = `✅ *Stream Vault — Pengisian Data Selesai!*\n\n` +
    `Semua metadata film dan episode series telah berhasil diisi ke Supabase.\n\n` +
    `⏱ Total waktu: ${formatDuration(elapsed)}\n` +
    `🕐 Selesai: ${now()}`;

  console.log('');
  console.log('╔══════════════════════════════════════════════════════╗');
  console.log('║            ✅ PENGISIAN DATA SELESAI!                 ║');
  console.log('╚══════════════════════════════════════════════════════╝');
  console.log(`   Total waktu berjalan: ${formatDuration(elapsed)}`);
  console.log(`   Selesai pada: ${now()}`);
  console.log('');

  await sendNotification(
    '✅ Stream Vault — Selesai!',
    `Semua data berhasil diisi!\nTotal waktu: ${formatDuration(elapsed)}\nSelesai: ${now()}`
  );

  console.log('💤 Pekerjaan selesai. Menghindari restart Railway dengan tidur selamanya...');
  setInterval(() => {
    console.log(`[IDLE] Worker dalam mode siaga - ${now()}`);
  }, 1000 * 60 * 60 * 12);
}

runWorker().catch(async err => {
  console.error('\n❌ FATAL:', err.message);
  await sendNotification(
    '❌ Stream Vault — Error!',
    `Terjadi error fatal:\n${err.message}\n\nCek log Railway untuk detail.`,
    true
  );
  console.log('💤 Menghindari restart Railway akibat error dengan tidur selamanya...');
  setInterval(() => {
    console.log(`[IDLE-ERROR] Worker dalam mode siaga setelah error - ${now()}`);
  }, 1000 * 60 * 60 * 12);
});
