import "server-only";

import { apiAction, apiGet } from "@/lib/server/api";
import { getCourses } from "@/lib/server/courses";

// A bundle clubs several existing courses together in an order. Enrollment
// and progress stay per course — see docs/courses.md "Bundles".
export interface Bundle {
  id: string;
  org_id: string;
  creator_id: string;
  title: string;
  slug: string;
  description: string | null;
  cover_url: string | null;
  status: "draft" | "published";
  course_count: number;
  created_at: string;
  updated_at: string;
}

interface BundleProgress {
  completed: number;
  total: number;
  pct: number;
}

interface BundleCourse {
  id: string;
  slug: string;
  title: string;
  description: string | null;
  cover_url: string | null;
  difficulty: string;
  status: string;
  is_free: boolean;
  price_cents: number;
  estimated_hours: number | null;
  position: number;
  is_enrolled: boolean;
  progress: BundleProgress;
}

export interface BundleDetail extends Bundle {
  courses: BundleCourse[];
  progress: BundleProgress;
}

export interface BundleRef {
  id: string;
  slug: string;
  title: string;
}

export async function getBundles(): Promise<Bundle[]> {
  const data = await apiGet<{ bundles: Bundle[] }>("/api/bundles");
  return data.bundles ?? [];
}

// Every bundle in the org, drafts included — instructors+ only (403 otherwise).
export async function getManagedBundles(): Promise<Bundle[]> {
  const data = await apiGet<{ bundles: Bundle[] }>("/api/bundles?include_drafts=true");
  return data.bundles ?? [];
}

export async function getBundleBySlug(slug: string): Promise<BundleDetail> {
  return apiGet<BundleDetail>(`/api/bundles/by-slug/${slug}`);
}

// Editor view: drafts and unpublished courses included; null when no bundle has the slug.
export async function getManagedBundleBySlug(slug: string): Promise<BundleDetail | null> {
  const res = await apiAction<BundleDetail>("GET", `/api/bundles/by-slug/${slug}?include_drafts=true`);
  if (res.status === 404) return null;
  if (!res.ok || !res.data) throw new Error(res.error ?? "Could not load the bundle.");
  return res.data;
}

export interface PickableCourse {
  id: string;
  title: string;
  status: string;
}

// Courses an instructor can put in a bundle: the published catalog plus their
// own drafts — the same merge the /courses page does.
export async function getPickableCourses(): Promise<PickableCourse[]> {
  const [published, own] = await Promise.all([getCourses(), getCourses("?role=instructor")]);
  const byID = new Map<string, PickableCourse>();
  for (const c of [...published, ...own]) {
    if (c.status !== "archived") byID.set(c.id, { id: c.id, title: c.title, status: c.status });
  }
  return [...byID.values()].sort((a, b) => a.title.localeCompare(b.title));
}
