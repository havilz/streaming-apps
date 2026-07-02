import { NextRequest, NextResponse } from "next/server";
import { getDb } from "@/lib/db";

export const dynamic = "force-dynamic";

/**
 * GET /api/movies
 * Returns cached movies from SQLite database.
 * Supports query params: ?type=movie|series&limit=50&offset=0
 */
export async function GET(request: NextRequest) {
  try {
    const db = getDb();
    const { searchParams } = new URL(request.url);

    const type = searchParams.get("type"); // "movie" or "series"
    const limit = Math.min(parseInt(searchParams.get("limit") || "50"), 100);
    const offset = parseInt(searchParams.get("offset") || "0");
    const search = searchParams.get("q");

    let query = "SELECT * FROM movies";
    const conditions: string[] = [];
    const params: Record<string, unknown> = {};

    if (type) {
      conditions.push("content_type = @type");
      params.type = type;
    }

    if (search) {
      conditions.push("(title LIKE @search OR original_title LIKE @search)");
      params.search = `%${search}%`;
    }

    if (conditions.length > 0) {
      query += " WHERE " + conditions.join(" AND ");
    }

    query += " ORDER BY created_at DESC LIMIT @limit OFFSET @offset";
    params.limit = limit;
    params.offset = offset;

    const movies = db.prepare(query).all(params) as Record<string, any>[];

    // Get total count for pagination
    let countQuery = "SELECT COUNT(*) as total FROM movies";
    if (conditions.length > 0) {
      countQuery += " WHERE " + conditions.join(" AND ");
    }
    const countParams = { ...params };
    delete countParams.limit;
    delete countParams.offset;
    const countResult = db.prepare(countQuery).get(countParams) as { total: number };

    // Parse genres JSON string back to array for each movie
    const parsed = movies.map((m: Record<string, any>) => ({
      ...m,
      genres: m.genres ? JSON.parse(m.genres as string) : [],
    }));

    return NextResponse.json({
      data: parsed,
      total: countResult.total,
      limit,
      offset,
    });
  } catch (error) {
    console.error("[api/movies] Error:", error);
    return NextResponse.json(
      { error: "Failed to fetch movies", details: String(error) },
      { status: 500 }
    );
  }
}
