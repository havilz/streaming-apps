import type { Metadata } from "next";
import { Inter, Outfit } from "next/font/google";
import Link from "next/link";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

const outfit = Outfit({
  subsets: ["latin"],
  variable: "--font-outfit",
  display: "swap",
});

export const metadata: Metadata = {
  title: "StreamVault — Nonton Film & Serial TV HD",
  description:
    "Nonton atau streaming film, serial TV terbaru dalam format HD secara gratis. Update otomatis setiap hari.",
  icons: { icon: "/favicon.ico" },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="id"
      className={`${inter.variable} ${outfit.variable} antialiased`}
    >
      <body className="min-h-screen flex flex-col bg-bg-dark text-text-primary">
        {/* Navbar */}
        <header className="navbar-glass fixed top-0 left-0 right-0 z-50">
          <div className="max-w-[1400px] mx-auto px-4 sm:px-6 lg:px-10">
            <div className="flex items-center justify-between h-16">
              {/* Logo */}
              <Link href="/" className="brand-logo">
                StreamVault
              </Link>

              {/* Nav Links */}
              <nav className="hidden md:flex items-center gap-1">
                <Link href="/" className="nav-link active">
                  Beranda
                </Link>
                <Link href="/?type=movie" className="nav-link">
                  Film
                </Link>
                <Link href="/?type=series" className="nav-link">
                  Serial TV
                </Link>
              </nav>

              {/* Mobile menu icon */}
              <button
                className="md:hidden text-text-primary"
                aria-label="Menu"
              >
                <svg
                  width="24"
                  height="24"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                  strokeLinecap="round"
                >
                  <path d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              </button>
            </div>
          </div>
        </header>

        {/* Main Content */}
        <main className="flex-1 pt-16">{children}</main>

        {/* Footer */}
        <footer className="footer mt-12">
          <div className="max-w-[1400px] mx-auto">
            <p>
              StreamVault tidak menghosting, menyimpan, atau mendistribusikan
              file media apa pun. Semua konten diambil otomatis dari penyedia
              pihak ketiga di internet.
            </p>
            <p className="mt-1 opacity-50">
              © {new Date().getFullYear()} StreamVault
            </p>
          </div>
        </footer>
      </body>
    </html>
  );
}
