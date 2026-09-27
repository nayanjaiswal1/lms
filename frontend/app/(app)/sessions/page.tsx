import { redirect } from "next/navigation";
import ROUTES from "@/lib/routes";

// Sessions moved onto the Calendar page; keep old links/bookmarks working.
export default function SessionsPage() {
  redirect(`${ROUTES.CALENDAR}#sessions`);
}
