import type { Metadata } from "next";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { apiGet } from "@/lib/server/api";
import { OrgSearchInput } from "@/app/platform/features/org-search-input";
import ROUTES from "@/lib/routes";
import type { AdminOrgSummary } from "@/lib/orgs/types";

export const metadata: Metadata = {
  title: "Features — Platform Console",
};

function statusVariant(status: string): "default" | "secondary" | "destructive" | "outline" {
  switch (status) {
    case "active": return "default";
    case "suspended": return "destructive";
    default: return "outline";
  }
}

export default async function PlatformFeaturesPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string }>;
}) {
  const { search } = await searchParams;
  const qs = search?.trim() ? `?search=${encodeURIComponent(search.trim())}` : "";
  const { orgs } = await apiGet<{ orgs: AdminOrgSummary[] }>(`/api/admin/orgs${qs}`);

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Features</h1>
          <p className="text-muted-foreground mt-1">
            Pick an organisation to turn its features on or off.
          </p>
        </div>
      </div>

      <div className="mt-6">
        <OrgSearchInput />
      </div>

      <section className="mt-6">
        {orgs.length === 0 ? (
          <div className="empty-state">
            <p className="text-muted-foreground">No organisations found.</p>
          </div>
        ) : (
          <div className="table-responsive">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-muted-foreground">
                  <th className="pb-2 pr-6 font-medium">Organisation</th>
                  <th className="pb-2 pr-4 font-medium">Slug</th>
                  <th className="pb-2 font-medium">Status</th>
                </tr>
              </thead>
              <tbody>
                {orgs.map((org) => (
                  <tr className="border-b border-border last:border-0 hover:bg-muted/50 whitespace-nowrap" key={org.id}>
                    <td className="py-3 pr-6">
                      <Link className="font-medium hover:underline" href={ROUTES.platformOrgFeatures(org.id)}>
                        {org.name}
                      </Link>
                    </td>
                    <td className="py-3 pr-4 font-mono text-xs text-muted-foreground">{org.slug}</td>
                    <td className="py-3">
                      <Badge variant={statusVariant(org.status)}>{org.status}</Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
