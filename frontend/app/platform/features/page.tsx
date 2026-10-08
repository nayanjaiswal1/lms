import type { Metadata } from "next";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { apiGet } from "@/lib/server/api";
import { OrgSearchInput } from "@/app/platform/features/org-search-input";
import ROUTES from "@/lib/routes";
import type { AdminOrgSummary } from "@/lib/orgs/types";
import { ResponsiveTable } from "@/components/ui/responsive-table";

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
  searchParams: Promise<{ search?: string; cursor?: string }>;
}) {
  const { search, cursor } = await searchParams;
  const params = new URLSearchParams();
  if (search?.trim()) params.set("search", search.trim());
  if (cursor) params.set("cursor", cursor);
  const qs = params.size ? `?${params}` : "";
  const { items: orgs, next_cursor: nextCursor } = await apiGet<{
    items: AdminOrgSummary[];
    next_cursor?: string;
  }>(`/api/admin/orgs${qs}`);

  const nextParams = new URLSearchParams(params);
  if (nextCursor) nextParams.set("cursor", nextCursor);

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
          <ResponsiveTable>
            <table className="w-full text-sm">
              <thead>
                <tr className="whitespace-nowrap border-b border-border text-left text-muted-foreground">
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
          </ResponsiveTable>
        )}
        {nextCursor && (
          <Link className="mt-4 inline-block text-sm font-medium hover:underline" href={`?${nextParams}`}>
            Next page
          </Link>
        )}
      </section>
    </div>
  );
}
