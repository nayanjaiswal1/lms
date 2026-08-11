import { notFound } from "next/navigation";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";

export default async function RoleDetailLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_PERMISSIONS)) {
    notFound();
  }

  return children;
}
