"use client";

import { useEffect, useRef, useState } from "react";

interface Subtitle {
  lang: string;
  label: string;
  path: string;
}

interface PlayerProps {
  episodeId: string;
  slug: string;
  isMovie: boolean;
  title: string;
}

export default function Player({ episodeId, slug, isMovie, title }: PlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [loading, setLoading] = useState(true);
  const [loadingStep, setLoadingStep] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [streamUrl, setStreamUrl] = useState<string | null>(null);
  const [subtitles, setSubtitles] = useState<Subtitle[]>([]);
  const [countdown, setCountdown] = useState(17);

  // Load Hls.js script dynamically
  const [hlsLoaded, setHlsLoaded] = useState(false);

  useEffect(() => {
    const scriptId = "hls-js-script";
    let script = document.getElementById(scriptId) as HTMLScriptElement | null;

    if (!script) {
      script = document.createElement("script");
      script.id = scriptId;
      script.src = "https://cdn.jsdelivr.net/npm/hls.js@1.4.14/dist/hls.min.js";
      script.async = true;
      script.onload = () => setHlsLoaded(true);
      document.body.appendChild(script);
    } else {
      setHlsLoaded(true);
    }
  }, []);

  // Fetch the playable stream URL
  useEffect(() => {
    setLoading(true);
    setError(null);
    setStreamUrl(null);
    setCountdown(17);
    setLoadingStep(0);

    // Mock countdown timer for UX
    const countdownInterval = setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          clearInterval(countdownInterval);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    // Progression of descriptive loader steps
    const steps = [
      "Menghubungkan ke server premium...",
      "Menghubungkan ke server premium...",
      "Menyiapkan enkripsi jalur streaming...",
      "Menyiapkan enkripsi jalur streaming...",
      "Membuka kunci berkas media (IPFS / Hoster)...",
      "Membuka kunci berkas media (IPFS / Hoster)...",
      "Membuat master playlist streaming...",
      "Membuat master playlist streaming...",
      "Hampir selesai, memuat buffer video...",
    ];

    const stepInterval = setInterval(() => {
      setLoadingStep((prev) => {
        if (prev >= steps.length - 1) {
          clearInterval(stepInterval);
          return prev;
        }
        return prev + 1;
      });
    }, 1800);

    let isMounted = true;

    async function fetchStream() {
      try {
        const res = await fetch(`/api/play/${episodeId}?slug=${slug}&isMovie=${isMovie}`);
        if (!res.ok) {
          const errData = await res.json();
          throw new Error(errData.error || "Gagal memutar video.");
        }
        const playInfo = await res.json();
        
        if (isMounted) {
          setStreamUrl(playInfo.url);
          setSubtitles(playInfo.subtitles || []);
          setLoading(false);
          clearInterval(countdownInterval);
          clearInterval(stepInterval);
        }
      } catch (err: unknown) {
        if (isMounted) {
          console.error(err);
          setError(err instanceof Error ? err.message : "Gagal memutar video.");
          setLoading(false);
          clearInterval(countdownInterval);
          clearInterval(stepInterval);
        }
      }
    }

    fetchStream();

    return () => {
      isMounted = false;
      clearInterval(countdownInterval);
      clearInterval(stepInterval);
    };
  }, [episodeId, slug, isMovie]);

  // Handle video player attachment
  useEffect(() => {
    if (loading || error || !streamUrl || !hlsLoaded) return;

    const video = videoRef.current;
    if (!video) return;

    // Reset video player sources
    video.src = "";

    // Access window.Hls if loaded from CDN
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const Hls = (window as any).Hls;

    if (Hls && Hls.isSupported()) {
      const hls = new Hls({
        maxBufferSize: 30 * 1024 * 1024, // 30MB buffer
        enableWorker: true,
        lowLatencyMode: true,
      });

      hls.loadSource(streamUrl);
      hls.attachMedia(video);
      
      hls.on(Hls.Events.MANIFEST_PARSED, () => {
        video.play().catch((err) => console.log("Autoplay blocked:", err));
      });

      hls.on(Hls.Events.ERROR, (event: unknown, data: { fatal: boolean; type: string }) => {
        if (data.fatal) {
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              console.log("Fatal network error encountered, trying to recover...");
              hls.startLoad();
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              console.log("Fatal media error encountered, trying to recover...");
              hls.recoverMediaError();
              break;
            default:
              console.log("Fatal error, cannot recover.");
              setError("Gagal memuat video stream. Silakan segarkan halaman.");
              hls.destroy();
              break;
          }
        }
      });

      return () => {
        hls.destroy();
      };
    } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
      // Native HLS support (Safari/iOS)
      video.src = streamUrl;
      video.addEventListener("loadedmetadata", () => {
        video.play().catch((err) => console.log("Autoplay blocked:", err));
      });
    } else {
      setError("Browser Anda tidak mendukung pemutaran video HLS (.m3u8).");
    }
  }, [loading, error, streamUrl, hlsLoaded]);

  const steps = [
    "Menghubungkan ke server premium...",
    "Menghubungkan ke server premium...",
    "Menyiapkan enkripsi jalur streaming...",
    "Menyiapkan enkripsi jalur streaming...",
    "Membuka kunci berkas media (IPFS / Hoster)...",
    "Membuka kunci berkas media (IPFS / Hoster)...",
    "Membuat master playlist streaming...",
    "Membuat master playlist streaming...",
    "Hampir selesai, memuat buffer video...",
  ];

  return (
    <div className="player-container aspect-video w-full rounded-xl overflow-hidden bg-black border border-white/5 relative group">
      {/* Loading overlay with countdown */}
      {loading && (
        <div className="absolute inset-0 bg-bg-dark/95 z-30 flex flex-col items-center justify-center gap-4 text-center px-6">
          <div className="relative flex items-center justify-center">
            {/* Spinning Loader */}
            <div className="w-16 h-16 rounded-full border-[3px] border-primary/20 border-t-primary animate-spin" />
            <span className="absolute text-sm font-semibold text-primary font-outfit">
              {countdown > 0 ? countdown : "•"}
            </span>
          </div>

          <div className="flex flex-col gap-1 mt-2">
            <p className="text-white text-base font-semibold tracking-wide">
              {steps[loadingStep] || "Menghubungkan..."}
            </p>
            <p className="text-text-muted text-xs">
              Sedang memproses bypass antrean CDN (bisa memakan waktu ~15-20 detik)
            </p>
          </div>
        </div>
      )}

      {/* Error overlay */}
      {error && (
        <div className="absolute inset-0 bg-bg-dark/95 z-30 flex flex-col items-center justify-center gap-4 text-center px-6">
          <div className="p-3 bg-red-950/30 text-primary border border-primary/20 rounded-full">
            <svg
              width="32"
              height="32"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <circle cx="12" cy="12" r="10" />
              <line x1="12" x2="12" y1="8" y2="12" />
              <line x1="12" x2="12.01" y1="16" y2="16" />
            </svg>
          </div>
          <div className="flex flex-col gap-1">
            <p className="text-white text-base font-semibold">{error}</p>
            <p className="text-text-muted text-xs">
              Silakan coba muat ulang halaman atau segarkan kembali server
            </p>
          </div>
          <button
            onClick={() => window.location.reload()}
            className="btn-play mt-2 text-xs py-2 px-5"
          >
            Segarkan Halaman
          </button>
        </div>
      )}

      {/* Video element */}
      <video
        ref={videoRef}
        className="w-full h-full object-contain"
        controls
        playsInline
        preload="metadata"
        title={title}
      >
        {subtitles.map((sub, idx) => (
          <track
            key={idx}
            kind="subtitles"
            src={sub.path}
            srcLang={sub.lang}
            label={sub.label}
            default={sub.lang === "id"}
          />
        ))}
      </video>
    </div>
  );
}
