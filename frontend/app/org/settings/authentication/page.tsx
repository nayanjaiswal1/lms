import type { Metadata } from "next";
import { redirect, notFound } from "next/navigation";
import { Shield } from "lucide-react";
import { getOrgAuthConfig } from "@/lib/orgs/server";
import { AuthConfigForm } from "@/app/org/settings/authentication/auth-config-form";
import { SectionHeader } from "@/components/shared/section-header";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";
import { getCurrentOrgId } from "@/lib/server/claims";

export const metadata: Metadata = {
  title: "Authentication — Organisation Settings",
};


export default async function AuthenticationPage() {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ORG)) {
    notFound();
  }

  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const config = await getOrgAuthConfig(orgId);

  return (
    <div className="space-y-6">
      <div className="card-base p-6">
        <SectionHeader
          description="Configure how your organisation members sign in."
          icon={Shield}
          title="Authentication"
        />

        <AuthConfigForm config={config} orgId={orgId} />
      </div>

      {/* Info callout */}
      <div className="rounded-lg border border-border bg-muted p-4">
        <p className="text-sm font-medium text-foreground mb-1">About SSO setup</p>
        <p className="text-sm text-muted-foreground">
          After enabling SSO, contact support to complete the identity provider configuration.
          Members will be prompted to sign in through your chosen provider on their next login.
        </p>
      </div>
    </div>
  );
}
