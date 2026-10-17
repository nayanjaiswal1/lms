import { getCurrentUser } from "@/lib/server/auth";
import { Sidebar } from "@/components/layout/sidebar";
import { TopBar } from "@/components/layout/top-bar";
import { MobileNav } from "@/components/layout/mobile-nav";
import { AnonProgressMigrator } from "@/components/courses/anon-progress-migrator";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await getCurrentUser();
  return (
    <div className="app-shell">
      <AnonProgressMigrator user={user} />
      <Sidebar user={user} />
      <div className="app-main">
        <MobileNav user={user} />
        <TopBar />
        <main className="app-content">{children}</main>
      </div>
    </div>
  );
}
