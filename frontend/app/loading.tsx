import { Skeleton } from "@/components/ui/skeleton";

/** Default route-level loading UI. Streamed in by Next while a page resolves. */
export default function Loading() {
  return (
    <div className="page-container form-stack py-8">
      <Skeleton className="h-8 w-48" />
      <Skeleton className="h-4 w-72" />
      <div className="card-grid mt-4">
        <Skeleton className="h-40" />
        <Skeleton className="h-40" />
        <Skeleton className="h-40" />
      </div>
    </div>
  );
}
