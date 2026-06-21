import { Skeleton } from "@/components/ui/skeleton";

export default function ResultLoading() {
  return (
    <div className="page-container-sm py-10">
      <div className="card-raised flex flex-col items-center gap-4 p-8">
        <Skeleton className="h-12 w-12 rounded-full" />
        <Skeleton className="h-10 w-24" />
        <Skeleton className="h-4 w-64" />
        <Skeleton className="h-10 w-40" />
      </div>
    </div>
  );
}
