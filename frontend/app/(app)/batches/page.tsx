import { redirect } from "next/navigation";
import ROUTES from "@/lib/routes";

// The batch list lives on the cohort-groups page, alongside the group
// hierarchy. Individual batch detail routes (/batches/[id]/...) are unaffected.
export default function BatchesPage() {
  redirect(ROUTES.COHORT_GROUPS);
}
