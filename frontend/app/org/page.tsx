import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { OrgLandingPage } from "@/components/landing/org-landing-page";
import { getCurrentOrgBranding } from "@/lib/orgs/server";
import { getPublicPricingTiers } from "@/lib/server/pricing";
import ROUTES from "@/lib/routes";

// Unlike app/page.tsx, this segment is a descendant of the root layout, so
// the root layout's `%s | {name}` title template applies normally here.
export const metadata: Metadata = {
  title: "Run your training program on your own tenant",
  description:
    "Role-based access, a shared wiki, batch chat, and proctored assessments for colleges, bootcamps, and companies. Self-hosted, free up to 10 seats.",
};

export default async function OrgLandingRoute() {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get("access_token")?.value;

  if (accessToken) {
    redirect(ROUTES.DASHBOARD);
  }

  const [{ name }, tiers] = await Promise.all([getCurrentOrgBranding(), getPublicPricingTiers("org")]);

  return <OrgLandingPage orgName={name ?? ""} tiers={tiers} />;
}
