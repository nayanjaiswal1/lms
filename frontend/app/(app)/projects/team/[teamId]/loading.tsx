import { Skeleton } from "@/components/ui/skeleton";

export default function MyProjectDetailLoading() {
  return (
    <div className="page-container">
      <div className="page-header items-start">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-64" />
          <Skeleton className="h-4 w-48" />
        </div>
        <div className="flex gap-2">
          <Skeleton className="h-10 w-24" />
          <Skeleton className="h-10 w-24" />
        </div>
      </div>
      <Skeleton className="mt-6 h-64 w-full" />
    </div>
  );
}
