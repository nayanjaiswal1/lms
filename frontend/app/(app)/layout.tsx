import { getCurrentUser } from "@/lib/server/auth";
import { Sidebar } from "@/components/layout/sidebar";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await getCurrentUser();
  return (
    <div className="app-shell">
      <Sidebar user={user} />
      <div className="app-main">
        <main className="app-content">{children}</main>
      </div>
    </div>
  );
}
