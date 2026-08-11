import type { Metadata } from "next";
import { redirect, notFound } from "next/navigation";
import { getOrgDomains } from "@/lib/orgs/server";
import { DomainList } from "@/app/org/settings/domains/domain-list";
import { AddDomainForm } from "@/app/org/settings/domains/add-domain-form";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";
import { getCurrentOrgId } from "@/lib/server/claims";

export const metadata: Metadata = {
  title: "Domains — Organisation Settings",
};


export default async function DomainsPage() {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ORG)) {
    notFound();
  }

  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const domains = await getOrgDomains(orgId);

  return (
    <div className="space-y-8">
      {/* Add domain */}
      <div className="card-base p-6">
        <h2 className="subsection-title text-foreground mb-1">Add a Domain</h2>
        <p className="text-sm text-muted-foreground mb-4">
          Verified domains allow members to join automatically with a matching email address.
        </p>
        <AddDomainForm orgId={orgId} />
      </div>

      {/* Domain list */}
      <div>
        <h2 className="subsection-title text-foreground mb-4">
          Configured Domains
        </h2>
        <DomainList domains={domains} orgId={orgId} />
      </div>
    </div>
  );
}
