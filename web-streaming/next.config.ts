import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  serverExternalPackages: ["got-scraping", "header-generator", "better-sqlite3"],
};

export default nextConfig;
