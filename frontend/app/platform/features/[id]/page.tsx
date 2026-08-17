import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { apiGet } from "@/lib/server/api";
import { OrgFeatureFlagRow, type OrgFeatureFlagData } from "@/app/platform/features/[id]/org-feature-flag-row";
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
  const [org, { flags }] = await Promise.all([
    fetchOrg(orgId),
    apiGet<{ flags: OrgFeatureFlagData[] }>(`/api/admin/orgs/${orgId}/feature-flags`),
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

      <section className="mt-8 card-base p-6">
        {flags.map((flag) => (
          <OrgFeatureFlagRow flag={flag} key={flag.key} orgId={orgId} />
        ))}
      </section>
    </div>
  );
}
