import { NextRequest, NextResponse } from "next/server";
import { fetchPlayInfo } from "@/lib/scraper";

export const dynamic = "force-dynamic";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ episodeId: string }> }
) {
  const { episodeId } = await params;
  const { searchParams } = new URL(request.url);
  const slug = searchParams.get("slug") || "";
  const isMovie = searchParams.get("isMovie") === "true";

  if (!slug) {
    return NextResponse.json({ error: "Missing slug parameter" }, { status: 400 });
  }

  try {
    const playInfo = await fetchPlayInfo(episodeId, slug, isMovie);
    if (!playInfo) {
      return NextResponse.json({ error: "Failed to resolve streaming sources" }, { status: 500 });
    }
    return NextResponse.json(playInfo);
  } catch (error) {
    console.error("[api/play] Error:", error);
    return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
  }
}
