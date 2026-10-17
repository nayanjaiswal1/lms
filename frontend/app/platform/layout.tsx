import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/server/auth";
import { Sidebar } from "@/components/layout/sidebar";
import { MobileNav } from "@/components/layout/mobile-nav";
import { TopBar } from "@/components/layout/top-bar";
import ROUTES from "@/lib/routes";

export default async function PlatformLayout({ children }: { children: React.ReactNode }) {
  const user = await getCurrentUser();
  if (!user || user.platform_role !== "super_admin") redirect(ROUTES.DASHBOARD);

  return (
    <div className="app-shell">
      <Sidebar user={user} />
      <div className="app-main">
        <MobileNav user={user} />
        <TopBar />
        <main className="app-content">{children}</main>
      </div>
    </div>
  );
}
