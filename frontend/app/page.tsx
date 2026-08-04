import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { LandingPage } from "@/components/landing/landing-page";
import { getPublicCourses } from "@/lib/server/courses";
import { getCurrentOrgBranding } from "@/lib/orgs/server";
import ROUTES from "@/lib/routes";

// Next's title.template (defined in the root layout) only cascades to
// DESCENDANT segments — a page.tsx co-located with the layout.tsx that
// defines the template does not inherit it. So the root page has to append
// the org's brand itself instead of relying on the template like every
// other page does.
export async function generateMetadata(): Promise<Metadata> {
  const { name } = await getCurrentOrgBranding();
  return {
    title: `Courses, labs, and mentoring in one place | ${name || "MindForge"}`,
    description:
      "Browse ready-to-enroll courses with hands-on labs, assessments, and mentoring. Free to sign up.",
  };
}

export default async function RootPage() {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get("access_token")?.value;

  if (accessToken) {
    redirect(ROUTES.DASHBOARD);
  }

  const { total } = await getPublicCourses(1);

  return <LandingPage total={total} />;
}
