import { notFound } from "next/navigation";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { apiGet } from "@/lib/server/api";
import { WarmPoolTable, type WarmPoolRowData } from "./warm-pool-table";

export default async function WarmPoolsPage() {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ORG)) {
    notFound();
  }

  const { labs } = await apiGet<{ labs: WarmPoolRowData[] }>("/api/admin/labs/warm-pools");

  return (
    <div className="page-container py-8">
      <WarmPoolTable labs={labs} />
    </div>
  );
}
