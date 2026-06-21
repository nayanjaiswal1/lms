import type { ReactNode } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { OrgSettingsMobileNav, OrgSettingsDesktopNav } from "@/app/org/settings/settings-nav";
import ROUTES from "@/lib/routes";

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

export default async function OrgSettingsLayout({
  children,
}: {
  children: ReactNode;
}) {
  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  return (
    <div className="page-container min-h-dvh">
      <div className="py-6 lg:py-10">
        <h1 className="text-2xl font-semibold text-foreground mb-6">
          Organisation Settings
        </h1>

        {/* Mobile tab row */}
        <OrgSettingsMobileNav />

        {/* Desktop two-column: sidebar + content */}
        <div className="lg:flex lg:gap-8">
          <OrgSettingsDesktopNav />
          <main className="flex-1 min-w-0">{children}</main>
        </div>
      </div>
    </div>
  );
}
