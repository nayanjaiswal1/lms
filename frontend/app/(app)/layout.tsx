import { getCurrentUser } from "@/lib/server/auth";
import { Sidebar } from "@/components/layout/sidebar";
import { MobileNav } from "@/components/layout/mobile-nav";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await getCurrentUser();
  return (
    <div className="app-shell">
      <Sidebar user={user} />
      <div className="app-main">
        <MobileNav user={user} />
        <main className="app-content">{children}</main>
      </div>
    </div>
  );
}
