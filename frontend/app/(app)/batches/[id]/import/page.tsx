import { redirect } from "next/navigation";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ job?: string }>;
}

// Bulk import now runs inside a modal on the batch page (see bulk-import-panel.tsx)
// instead of its own route. This shim keeps old bookmarked/shared links — including
// in-progress "?job=" links — working by forwarding them to the modal's URL state.
export default async function BatchImportRedirect({ params, searchParams }: Props) {
  const { id } = await params;
  const { job } = await searchParams;

  const query = new URLSearchParams({ "bulk-import": "true" });
  if (job) {
    query.set("job", job);
    query.set("step", "progress");
  }
  redirect(`${ROUTES.batch(id)}?${query.toString()}`);
}
