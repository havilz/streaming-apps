# **Future Release Planning For Version 1.0.0.4**

Rencana pembaruan mendatang untuk menambahkan fitur interaktif pengguna menggunakan ekosistem Supabase secara aman tanpa merusak atau mereset data katalog lama.

---

## **Bagian 1: Skema Database (PostgreSQL DDL)**

Seluruh tabel berikut diletakkan di dalam skema **`public`** dan dihubungkan secara aman ke skema **`auth`** bawaan Supabase.

### 1. Tabel Profil (`public.profiles`)
Menampung data profil publik pengguna. Data tersinkronisasi otomatis dengan `auth.users` menggunakan database trigger saat pendaftaran awal.

```sql
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  phone_number TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Jalankan Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Policy: User hanya dapat membaca profil mereka sendiri
CREATE POLICY "Allow individual read" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- Policy: User hanya dapat memperbarui profil mereka sendiri
CREATE POLICY "Allow individual update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Database Trigger: Otomatis membuat baris profil saat user mendaftar di Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, phone_number, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)), -- Gunakan username dari metadata, atau default bagian awal email
    NEW.raw_user_meta_data->>'phone_number',
    now()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### 2. Tabel Favorit (`public.favorites`)
Mencatat daftar konten favorit pengguna dengan relasi polimorfik.

```sql
CREATE TABLE public.favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_id UUID NOT NULL, -- ID dari tabel movies atau series
  content_type TEXT NOT NULL CHECK (content_type IN ('movie', 'series')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, content_id) -- Mencegah duplikasi data favorit
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to manage their own favorites" ON public.favorites
  FOR ALL USING (auth.uid() = user_id);
```

### 3. Tabel Bookmark (`public.bookmarks`)
Mencatat daftar tontonan nanti (watchlist) pengguna dengan relasi polimorfik.

```sql
CREATE TABLE public.bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_id UUID NOT NULL, -- ID dari tabel movies atau series
  content_type TEXT NOT NULL CHECK (content_type IN ('movie', 'series')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, content_id)
);

ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to manage their own bookmarks" ON public.bookmarks
  FOR ALL USING (auth.uid() = user_id);
```

### 4. Tabel Riwayat Tontonan (`public.watch_history`)
Menyimpan riwayat tontonan dan progres detik terakhir dari pemutaran video.

```sql
CREATE TABLE public.watch_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_id UUID NOT NULL, -- ID dari tabel movies atau series
  content_type TEXT NOT NULL CHECK (content_type IN ('movie', 'series')),
  episode_id UUID REFERENCES public.episodes(id) ON DELETE CASCADE, -- NULL jika movie, berisi ID episode jika series
  position INTEGER NOT NULL DEFAULT 0, -- Detik terakhir video ditonton
  duration INTEGER NOT NULL DEFAULT 0, -- Durasi total video dalam detik
  completed BOOLEAN NOT NULL DEFAULT FALSE, -- TRUE jika posisi menonton mencapai >= 90% durasi
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, content_id, episode_id)
);

ALTER TABLE public.watch_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to manage their own watch history" ON public.watch_history
  FOR ALL USING (auth.uid() = user_id);
```

---

## **Bagian 2: Alur Logika Fitur (Feature Logic & Flows)**

### 1. Alur & Metode Autentikasi (Supabase Auth)

#### A. Metode Autentikasi yang Digunakan:
1. **Email & Password**: Metode login tradisional yang aman dan umum.
2. **Phone Number & Password**: Alternatif login cepat menggunakan nomor telepon terdaftar.
3. **Google Sign-In (OAuth)**: Solusi login instan satu ketuk menggunakan akun Google bawaan perangkat pengguna.

#### B. Alur Pendaftaran Pengguna Baru (Sign Up Flow):
```
[User mengisi form: Email/No. Telepon, Password, Username]
                            |
                            v
[Aplikasi memanggil fungsi SignUp Supabase]
  - supabase.auth.signUp(email, password, data: { 'username': username })
                            |
                            v
[Supabase Auth memvalidasi & membuat baris di auth.users]
                            |
                            v (Database Trigger Otomatis Terpicu)
[SQL Trigger memicu public.handle_new_user()]
  - Menyisipkan { id, username, phone_number, created_at } ke public.profiles
                            |
                            v
[Kembalikan objek Session token ke aplikasi mobile]
  - User berhasil terdaftar, otomatis login, dan diarahkan ke Home.
```

#### C. Alur Masuk Pengguna (Sign In Flow - Email/Phone):
```
[User memasukkan Email/No. Telepon & Password]
                            |
                            v
[Aplikasi memanggil fungsi SignIn Supabase]
  - supabase.auth.signInWithPassword(email/phone, password)
                            |
                            v
[Supabase memvalidasi kredensial pengguna]
  |
  +---> TIDAK VALID: Kembalikan pesan error (Email/Password salah).
  |
  +---> VALID: Kembalikan Session token baru.
                  |
                  v
[Aplikasi menyimpan Session di Secure Storage & Mengubah State ke Authenticated]
                  |
                  v
[Arahkan pengguna ke Halaman Utama (Home)]
```

#### D. Alur Google Sign-In (OAuth Flow):
```
[User menekan tombol "Sign in with Google"]
                            |
                            v
[Aplikasi memanggil Google Sign-In SDK lokal (native dialog)]
                            |
                            v
[Google SDK mengembalikan ID Token & Access Token]
                            |
                            v
[Aplikasi meneruskan Token tersebut ke Supabase Auth]
  - supabase.auth.signInWithIdToken(provider: google, idToken, accessToken)
                            |
                            v
[Supabase memvalidasi token Google ke Google Server API]
  |
  +---> TIDAK VALID: Batalkan proses login & tampilkan error.
  |
  +---> VALID: Apakah ini user baru?
                  |
                  +--- YA: Buat data auth.users baru (memicu trigger profiles).
                  +--- TIDAK: Ambil sesi user yang sudah ada.
                            |
                            v
[Kembalikan Session token baru ke aplikasi mobile & Arahkan ke Home]
```

#### E. Alur Persistensi Sesi Aplikasi (Session Persistence Flow):
```
[Aplikasi pertama kali dibuka (Cold Start / Splash Screen)]
                            |
                            v
[Aplikasi memeriksa Supabase Session lokal yang tersimpan]
  - final session = supabase.auth.currentSession
                            |
[Apakah Sesi Tersedia & Aktif?]
  |
  +---> TIDAK: Arahkan ke Welcome / Login Screen.
  |
  +---> YA: Apakah token sesi sudah kedaluwarsa (Expired)?
              |
              +---> TIDAK: Arahkan langsung ke Halaman Utama (Home).
              |
              +---> YA: Jalankan Auto-Refresh Sesi di latar belakang.
                          - Berhasil -> Arahkan ke Halaman Utama (Home).
                          - Gagal -> Hapus sesi & arahkan ke Login Screen.
```

---

### 2. Alur "Continue Watching" (Riwayat & Resume Video)

#### A. Alur Penyimpanan Progres Tontonan (Save Progress Flow):
```
[Video Sedang Berjalan]
          |
          v (Setiap 5 detik sekali / throttling)
[Hitung Posisi & Durasi Video]
  - position = controller.value.position.inSeconds
  - duration = controller.value.duration.inSeconds
          |
[Validasi Status Completed]
  - Jika (position / duration) >= 0.90 -> completed = TRUE, posisi di-reset ke 0 (karena dianggap sudah selesai menonton).
  - Jika tidak -> completed = FALSE.
          |
          v
[Panggil API Supabase: Upsert Data]
  - Masukkan data { user_id, content_id, content_type, episode_id, position, duration, completed }
  - Database melakukan pembaruan jika data (user_id, content_id, episode_id) sudah terdaftar sebelumnya.
```

#### B. Alur Melanjutkan Pemutaran (Resume Playback Flow):
```
[User Membuka Halaman Detail / klik tombol Play]
          |
          v
[Aplikasi melakukan Fetch Query ke public.watch_history]
  - Filter berdasarkan user_id dan content_id (serta episode_id jika serial)
          |
[Apakah Data Watch History Ditemukan?]
  +---> TIDAK: Mulai video dari posisi 0 (awal).
  |
  +---> YA: Apakah completed == TRUE?
          |
          +---> YA: Mulai video dari posisi 0 (awal).
          |
          +---> TIDAK: Tampilkan dialog popup:
                "Lanjutkan menonton dari [Menit:Detik] terakhir?"
                |
                +--- User pilih YA: Lakukan controller.seekTo(position).
                +--- User pilih TIDAK: Mulai video dari posisi 0.
```

---

### 2. Alur "Pusat Notifikasi & Pesan" (Notification Center Flow)

#### A. Pusat Notifikasi Pesan (Message Center):
```
[Administrator merilis pengumuman di tabel public.messages]
          |
          v
[User membuka aplikasi mobile]
          |
          v
[Aplikasi membandingkan public.messages dengan profile.last_read_announcements]
          |
[Ada pesan baru yang dibuat setelah last_read_announcements?]
  +---> YA: Tampilkan indikator lencana merah (red badge) pada ikon lonceng.
  +---> TIDAK: Sembunyikan indikator lencana merah.
          |
          v
[User membuka inbox -> memuat seluruh daftar pesan]
  - Perbarui profile.last_read_announcements ke waktu saat ini (menghapus red badge).
```

#### B. Notifikasi Push Serial Baru (FCM Push Notification):
```
[Edge Function melakukan sinkronisasi otomatis / Sync Cron]
          |
          v
[Terdeteksi episode baru dimasukkan ke tabel public.episodes]
          |
          v
[Database Trigger memanggil Edge Function 'send-push-notification']
          |
          v
[Edge Function menarik semua user_id dari public.favorites yang memiliki series_id terkait]
          |
          v
[Kirim pesan Push via Firebase Cloud Messaging (FCM) ke perangkat terdaftar milik pengguna]
```

---

### 3. Alur "Pemeriksa Versi & Pembaruan Otomatis" (Version Checker & Auto-Update Flow)

```
[Aplikasi Mobile Booting / Startup]
          |
          v
[Aplikasi mengambil metadata versi terbaru dari public.app_versions]
  - Ambil: version_code (misal: 4), critical_update (boolean), download_url (APK file link)
          |
[Apakah version_code Supabase > local_version_code?]
  |
  +---> TIDAK: Lanjutkan masuk ke halaman utama (Home).
  |
  +---> YA: Tampilkan Dialog Pembaruan Aplikasi.
          |
          +---> Apakah critical_update == TRUE?
                  |
                  +---> YA: Kunci UI (User tidak bisa melewati dialog, wajib update).
                  +---> TIDAK: Berikan tombol "Nanti Saja" untuk melewati.
          |
          v (User klik "Update Sekarang")
[Aplikasi mendownload berkas APK via background downloader]
          |
          v (Unduhan selesai)
[Trigger Intent Paket Installer Android]
  - Memanggil platform channel Android untuk menginstal berkas APK secara langsung (In-App Auto-Update).
```

---

### 4. Alur "Peningkatan Penanganan Error & Cache Poster" (Better Error Handling & Image Caching)

#### A. Alur Penanganan Error (Better Error Handling):
```
[Request API / Scraper Pemutaran Video Terjadi Kegagalan]
          |
          v
[Interseptor Intersep HTTP Error / Exception]
  - Kelompokkan error ke tipe kelas khusus:
    - Tidak ada internet -> NoConnectionException
    - Cloudflare diblokir -> CloudflareBypassException
    - Rate limit -> RateLimitException (429)
    - Link video mati -> StreamExpiredException
          |
          v
[State Notifier memicu State UI ke Error State]
          |
          v
[Tampilkan Screen Error khusus dengan tombol "Coba Lagi" yang terhubung ke Callback fungsi asal]
```

#### B. Alur Cache Poster (Image Caching Flow):
```
[Grid Konten Halaman Utama Memuat Poster Gambar]
          |
          v
[Aplikasi memanggil Widget CachedNetworkImage]
          |
[Apakah berkas gambar sudah ter-cache di media penyimpanan lokal?]
  |
  +---> YA: Muat gambar secara instan dari penyimpanan lokal tanpa request internet.
  |
  +---> TIDAK: Ambil gambar dari URL CDN Supabase/TMDB.
          |
          v
[Simpan berkas gambar ke cache lokal (Max Age: 7 Hari, Limit: 500 Berkas)]
  - Tampilkan gambar menggunakan efek transisi memudar (fade-in) agar scrolling Grid terasa sangat mulus.
```
