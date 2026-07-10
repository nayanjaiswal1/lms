import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/server/auth";
import { PlatformSidebar } from "@/components/layout/platform-sidebar";
import { PlatformMobileNav } from "@/components/layout/platform-mobile-nav";
import ROUTES from "@/lib/routes";

export default async function PlatformLayout({ children }: { children: React.ReactNode }) {
  const user = await getCurrentUser();
  if (!user || user.platform_role !== "super_admin") redirect(ROUTES.DASHBOARD);

  return (
    <div className="app-shell">
      <PlatformSidebar user={user} />
      <div className="app-main">
        <PlatformMobileNav user={user} />
        <main className="app-content">{children}</main>
      </div>
    </div>
  );
}
