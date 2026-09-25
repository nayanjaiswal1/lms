import "server-only";

import { apiGet, apiGetPublic } from "@/lib/server/api";
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
  try {
    return await apiGetPublic<PublicProfile>(`/api/profile/public/${slug}`, { revalidate: 60 });
  } catch {
    return null;
  }
}
