import "server-only";
import { cookies } from "next/headers";
import { apiGet } from "@/lib/server/api";
import type { AuthMeResponse } from "@/lib/server/auth";
import type { FeatureConfig } from "@/lib/server/features";
import type { ActiveLabSession } from "@/lib/labs";

// GET /api/me/bootstrap merges the app shell's per-render reads (auth/me,
// permissions, features, active lab, current org) into one backend call.
// A part is absent when its underlying endpoint failed — each reader keeps its
// own fallback, exactly as when these were separate calls.
export interface Bootstrap {
  me?: AuthMeResponse;
  permissions?: { permissions: string[] };
  features?: FeatureConfig;
  active_lab_sessions?: ActiveLabSession[];
  // Only the fields the app shell reads (lib/orgs/server.ts) — a shared lib
  // can't import the orgs feature's Org type (boundaries/dependencies).
  org?: { name: string; logo_url: string | null; org_type: string | null };
}

// apiGet is request-deduped, so every reader below shares one fetch per render.
// Never throws: the root layout also renders for logged-out visitors.
export async function getBootstrap(): Promise<Bootstrap> {
  // Logged-out visitor (landing, login, register): the call can only 401, so
  // skip the backend round trip that would otherwise hold the root layout —
  // and with it the first paint of every public page — hostage.
  if (!(await cookies()).get("access_token")?.value) return {};
  try {
    return await apiGet<Bootstrap>("/api/me/bootstrap");
  } catch {
    return {};
  }
}
