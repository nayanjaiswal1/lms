// /api/whatnow/* — generic forwarder to the Go backend's What Now? domain.
// Auth/CSRF are enforced by the backend's own middleware; this route only
// forwards the session cookie and CSRF header.

import { NextRequest, NextResponse } from "next/server";
import { baseURL, authHeaders } from "@/lib/server/api";

export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ path: string[] }> };

async function forward(req: NextRequest, ctx: Ctx, method: string) {
  const { path } = await ctx.params;
  const url = `${baseURL()}/api/whatnow/${path.join("/")}${req.nextUrl.search}`;
  const hasBody = method === "POST" || method === "PATCH" || method === "PUT";
  const res = await fetch(url, {
    method,
    headers: await authHeaders(),
    body: hasBody ? await req.text() : undefined,
    cache: "no-store",
  });
  return new NextResponse(await res.text(), {
    status: res.status,
    headers: { "Content-Type": "application/json" },
  });
}

export const GET = (req: NextRequest, ctx: Ctx) => forward(req, ctx, "GET");
export const POST = (req: NextRequest, ctx: Ctx) => forward(req, ctx, "POST");
export const PATCH = (req: NextRequest, ctx: Ctx) => forward(req, ctx, "PATCH");
export const PUT = (req: NextRequest, ctx: Ctx) => forward(req, ctx, "PUT");
