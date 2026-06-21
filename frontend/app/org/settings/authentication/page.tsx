import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { Shield } from "lucide-react";
import { getOrgAuthConfig } from "@/lib/server/orgs";
import { AuthConfigForm } from "@/app/org/settings/authentication/auth-config-form";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Authentication — Organisation Settings",
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

export default async function AuthenticationPage() {
  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const config = await getOrgAuthConfig(orgId);

  return (
    <div className="space-y-6">
      <div className="card-base p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="h-9 w-9 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
            <Shield aria-hidden className="h-5 w-5 text-primary" />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-foreground">Authentication</h2>
            <p className="text-sm text-muted-foreground">
              Configure how your organisation members sign in.
            </p>
          </div>
        </div>

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
