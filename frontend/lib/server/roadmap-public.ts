import { cache } from "react";
import "server-only";

import { apiGetPublic } from "@/lib/server/api";
import type { Roadmap } from "@/lib/server/roadmap";

// Anonymous reads of the roadmap Discover gallery — no cookies forwarded.
export async function listPublicRoadmapsAnon(): Promise<Roadmap[]> {
  try {
    const data = await apiGetPublic<{ roadmaps: Roadmap[] }>("/api/roadmaps/discover", { revalidate: 60 });
    return data?.roadmaps ?? [];
  } catch {
    return [];
  }
}

// Same endpoint the signed-in roadmap detail page uses (lib/server/roadmap.ts
// getRoadmap) — the backend is auth-optional here (middleware.OptionalAuth):
// no cookie means it falls back to the is_public read-only view instead of
// the owner's, so no separate "public" path is needed.
export const getPublicRoadmapAnon = cache(async (id: string): Promise<Roadmap> => {
  return apiGetPublic<Roadmap>(`/api/roadmaps/${id}`, { revalidate: 60 });
});
