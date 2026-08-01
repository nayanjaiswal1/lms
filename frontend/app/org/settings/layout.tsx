import type { ReactNode } from "react";
import { redirect } from "next/navigation";
import { OrgSettingsMobileNav, OrgSettingsDesktopNav } from "@/app/org/settings/settings-nav";
import ROUTES from "@/lib/routes";
import { getCurrentOrgId } from "@/lib/server/claims";


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
