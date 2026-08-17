import { redirect } from "next/navigation";
import ROUTES from "@/lib/routes";

// Members management merged into /users (org role, invites, and RBAC roles
// now live on one page) — this route only exists to keep old links working.
export default function MembersPageRedirect() {
  redirect(ROUTES.USERS);
}
