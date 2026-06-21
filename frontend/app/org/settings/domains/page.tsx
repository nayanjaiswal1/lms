import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { getOrgDomains } from "@/lib/server/orgs";
import { DomainList } from "@/app/org/settings/domains/domain-list";
import { AddDomainForm } from "@/app/org/settings/domains/add-domain-form";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Domains — Organisation Settings",
};

async function getCurrentOrgId(): Promise<string | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString(),
    ) as { org_id?: string };
    return payload.org_id ?? null;
  } catch {
    return null;
  }
}

export default async function DomainsPage() {
  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const domains = await getOrgDomains(orgId);

  return (
    <div className="space-y-8">
      {/* Add domain */}
      <div className="card-base p-6">
        <h2 className="text-lg font-semibold text-foreground mb-1">Add a Domain</h2>
        <p className="text-sm text-muted-foreground mb-4">
          Verified domains allow members to join automatically with a matching email address.
        </p>
        <AddDomainForm orgId={orgId} />
      </div>

      {/* Domain list */}
      <div>
        <h2 className="text-lg font-semibold text-foreground mb-4">
          Configured Domains
        </h2>
        <DomainList domains={domains} orgId={orgId} />
      </div>
    </div>
  );
}
