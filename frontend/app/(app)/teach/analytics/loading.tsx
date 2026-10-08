import { Skeleton } from "@/components/ui/skeleton";

export default function TeachAnalyticsLoading() {
  return (
    <main className="page-container">
      <Skeleton className="mb-4 h-4 w-48" />
      <Skeleton className="mb-6 h-8 w-64" />
      <Skeleton className="mb-8 h-72 w-full" />
      <Skeleton className="h-64 w-full" />
    </main>
  );
}
