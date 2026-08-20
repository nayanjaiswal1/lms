import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { apiGet } from "@/lib/server/api";
import { OrgFeatureFlagRow, type OrgFeatureFlagData } from "@/app/platform/features/[id]/org-feature-flag-row";
import { OrgTierSelector } from "@/app/platform/features/[id]/org-tier-selector";
import { getPublicPricingTiers } from "@/lib/server/pricing";
import ROUTES from "@/lib/routes";
import type { AdminOrgSummary } from "@/lib/orgs/types";

interface PageProps {
  params: Promise<{ id: string }>;
}

async function fetchOrg(orgId: string): Promise<AdminOrgSummary | null> {
  const { orgs } = await apiGet<{ orgs: AdminOrgSummary[] }>(`/api/admin/orgs?search=${encodeURIComponent(orgId)}`);
  return orgs.find((o) => o.id === orgId) ?? null;
}

export const metadata: Metadata = {
  title: "Organisation Features — Platform Console",
};

export default async function PlatformOrgFeaturesPage({ params }: PageProps) {
  const { id: orgId } = await params;
  const [org, { flags }, orgTiers] = await Promise.all([
    fetchOrg(orgId),
    apiGet<{ flags: OrgFeatureFlagData[] }>(`/api/admin/orgs/${orgId}/feature-flags`),
    getPublicPricingTiers("org"),
  ]);

  if (!org) notFound();

  return (
    <div className="page-container">
      <Breadcrumb items={[{ href: ROUTES.PLATFORM_FEATURES, label: "Features" }, { label: org.name }]} />

      <div className="page-header">
        <div>
          <h1 className="page-title">Features — {org.name}</h1>
          <p className="text-muted-foreground mt-1">
            Turning a feature off here hides it for every member of this
            organisation, regardless of any per-member grant an org admin has set.
          </p>
        </div>
      </div>

      <section className="mt-8 card-base flex flex-col gap-3 p-6 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="font-semibold">Plan tier</h2>
          <p className="text-sm text-muted-foreground">
            Gates assessments and GitLab integration for this org — see docs/entitlements.md.
          </p>
        </div>
        <OrgTierSelector currentTierId={org.tier_id} orgId={orgId} tiers={orgTiers} />
      </section>

      <section className="mt-6 card-base p-6">
        {flags.map((flag) => (
          <OrgFeatureFlagRow flag={flag} key={flag.key} orgId={orgId} />
        ))}
      </section>
    </div>
  );
}
