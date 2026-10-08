import { Skeleton } from "@/components/ui/skeleton";

export default function CourseAnalyticsLoading() {
  return (
    <main className="page-container">
      <Skeleton className="mb-4 h-4 w-64" />
      <Skeleton className="mb-6 h-8 w-80" />
      <div className="grid-stats mb-8">
        <Skeleton className="h-24 w-full" />
        <Skeleton className="h-24 w-full" />
        <Skeleton className="h-24 w-full" />
      </div>
      <div className="grid-responsive-2 mb-8">
        <Skeleton className="h-72 w-full" />
        <Skeleton className="h-72 w-full" />
      </div>
      <Skeleton className="h-64 w-full" />
    </main>
  );
}
