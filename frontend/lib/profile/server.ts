import "server-only";

import { apiGet, baseURL } from "@/lib/server/api";
import type { Profile, ProfileOverview, PublicProfile } from "@/lib/profile/types";

export async function fetchMyProfile(): Promise<Profile | null> {
  try {
    return await apiGet<Profile>("/api/profile/me");
  } catch {
    return null;
  }
}

export async function fetchMyOverview(): Promise<ProfileOverview | null> {
  try {
    return await apiGet<ProfileOverview>("/api/profile/me/overview");
  } catch {
    return null;
  }
}

export async function fetchPublicProfile(slug: string): Promise<PublicProfile | null> {
  const res = await fetch(`${baseURL()}/api/profile/public/${slug}`, {
    cache: "no-store",
  });
  if (!res.ok) return null;
  const json = await res.json() as { data: PublicProfile };
  return json.data;
}
