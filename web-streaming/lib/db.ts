import Database from "better-sqlite3";
import path from "path";

const DB_PATH = path.join(process.cwd(), "dev.db");

let _db: Database.Database | null = null;

export function getDb(): Database.Database {
  if (!_db) {
    _db = new Database(DB_PATH);
    _db.pragma("journal_mode = WAL");
    _db.pragma("foreign_keys = ON");
    initTables(_db);
  }
  return _db;
}

function initTables(db: Database.Database) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS movies (
      id TEXT PRIMARY KEY,
      tmdb_id INTEGER,
      imdb_id TEXT,
      title TEXT NOT NULL,
      slug TEXT NOT NULL UNIQUE,
      original_title TEXT,
      overview TEXT,
      tagline TEXT,
      poster_path TEXT,
      backdrop_path TEXT,
      logo_path TEXT,
      content_type TEXT NOT NULL DEFAULT 'movie',
      release_date TEXT,
      runtime INTEGER,
      vote_average REAL,
      genres TEXT,
      quality TEXT,
      seasons TEXT,
      country TEXT,
      networks TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS episodes (
      id TEXT PRIMARY KEY,
      movie_id TEXT NOT NULL,
      season_number INTEGER DEFAULT 1,
      episode_number INTEGER DEFAULT 1,
      title TEXT,
      overview TEXT,
      still_path TEXT,
      runtime INTEGER,
      air_date TEXT,
      video_url TEXT,
      video_type TEXT DEFAULT 'unknown',
      video_fetched_at TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (movie_id) REFERENCES movies(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_movies_slug ON movies(slug);
    CREATE INDEX IF NOT EXISTS idx_movies_content_type ON movies(content_type);
    CREATE INDEX IF NOT EXISTS idx_episodes_movie_id ON episodes(movie_id);
  `);

  // Migrate existing databases to add seasons, country, and networks columns if not exists
  const columns = db.prepare("PRAGMA table_info(movies)").all() as { name: string }[];
  
  if (!columns.some((col) => col.name === "seasons")) {
    db.exec("ALTER TABLE movies ADD COLUMN seasons TEXT");
  }
  if (!columns.some((col) => col.name === "country")) {
    db.exec("ALTER TABLE movies ADD COLUMN country TEXT");
  }
  if (!columns.some((col) => col.name === "networks")) {
    db.exec("ALTER TABLE movies ADD COLUMN networks TEXT");
  }
}
