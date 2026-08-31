import "server-only";

import type { Roadmap } from "@/lib/server/roadmap";

function publicBase(): string {
  const url = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!url) throw new Error("BACKEND_URL is not configured");
  return url;
}

// Anonymous reads of the roadmap Discover gallery — no cookies forwarded.
export async function listPublicRoadmapsAnon(): Promise<Roadmap[]> {
  const res = await fetch(`${publicBase()}/api/roadmaps/discover`, { cache: "no-store" });
  if (!res.ok) return [];
  const body = await res.json() as { data: { roadmaps: Roadmap[] } };
  return body.data?.roadmaps ?? [];
}

// Same endpoint the signed-in roadmap detail page uses (lib/server/roadmap.ts
// getRoadmap) — the backend is auth-optional here (middleware.OptionalAuth):
// no cookie means it falls back to the is_public read-only view instead of
// the owner's, so no separate "public" path is needed.
export async function getPublicRoadmapAnon(id: string): Promise<Roadmap> {
  const res = await fetch(`${publicBase()}/api/roadmaps/${id}`, { cache: "no-store" });
  if (!res.ok) {
    const body = await res.json().catch(() => ({})) as { error?: string };
    throw new Error(body.error ?? "Roadmap not found.");
  }
  const body = await res.json() as { data: Roadmap };
  return body.data;
}
