"use client";

import { useRouter } from "next/navigation";
import { useCallback } from "react";

interface FilterDropdownsProps {
  type?: string;
  q?: string;
  genre?: string;
  year?: string;
  genres: string[];
  years: string[];
}

export default function FilterDropdowns({
  type,
  q,
  genre,
  year,
  genres,
  years,
}: FilterDropdownsProps) {
  const router = useRouter();

  const buildUrl = useCallback(
    (overrides: Record<string, string | undefined>) => {
      const p = new URLSearchParams();
      const merged = { type, q, page: undefined, genre, year, ...overrides };
      for (const [k, v] of Object.entries(merged)) {
        if (v) p.set(k, v);
      }
      const qs = p.toString();
      return qs ? `/?${qs}` : "/";
    },
    [type, q, genre, year]
  );

  function handleChange(key: string, value: string) {
    router.push(buildUrl({ [key]: value || undefined }));
  }

  const hasActiveFilter = genre || year;

  return (
    <div className="flex flex-wrap items-center gap-3 mb-8">
      {/* Genre Filter */}
      <div className="relative">
        <select
          value={genre || ""}
          onChange={(e) => handleChange("genre", e.target.value)}
          className={`appearance-none pl-4 pr-9 py-2 text-sm rounded-full border cursor-pointer transition-all duration-200 focus:outline-none focus:border-primary/60 bg-bg-elevated font-medium ${
            genre
              ? "border-primary/60 text-white bg-primary/10"
              : "border-white/10 text-text-muted hover:border-white/30 hover:text-white"
          }`}
        >
          <option value="">Genre</option>
          {genres.map((g) => (
            <option key={g} value={g}>
              {g}
            </option>
          ))}
        </select>
        <div className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-text-muted">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="m6 9 6 6 6-6" />
          </svg>
        </div>
      </div>

      {/* Year Filter */}
      <div className="relative">
        <select
          value={year || ""}
          onChange={(e) => handleChange("year", e.target.value)}
          className={`appearance-none pl-4 pr-9 py-2 text-sm rounded-full border cursor-pointer transition-all duration-200 focus:outline-none focus:border-primary/60 bg-bg-elevated font-medium ${
            year
              ? "border-primary/60 text-white bg-primary/10"
              : "border-white/10 text-text-muted hover:border-white/30 hover:text-white"
          }`}
        >
          <option value="">Tahun</option>
          {years.map((y) => (
            <option key={y} value={y}>
              {y}
            </option>
          ))}
        </select>
        <div className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-text-muted">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="m6 9 6 6 6-6" />
          </svg>
        </div>
      </div>

      {/* Reset Filters Button */}
      {hasActiveFilter && (
        <button
          onClick={() =>
            router.push(buildUrl({ genre: undefined, year: undefined, page: undefined }))
          }
          className="flex items-center gap-1.5 px-4 py-2 text-sm rounded-full border border-white/10 text-text-muted hover:text-white hover:border-white/30 transition-all duration-200"
        >
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="M18 6 6 18M6 6l12 12" />
          </svg>
          Reset Filter
        </button>
      )}
    </div>
  );
}
