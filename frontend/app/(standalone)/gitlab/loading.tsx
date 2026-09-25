import { Skeleton } from "@/components/ui/skeleton";

export default function GitLabPlanningLoading() {
  return (
    <div className="space-y-4 p-4 sm:p-6">
      <Skeleton className="h-12 w-full" />
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-12">
        <div className="grid grid-cols-2 gap-4 xl:col-span-7">
        {Array.from({ length: 4 }, (_, i) => <Skeleton className="h-48 w-full rounded-2xl" key={i} />)}
        </div>
        <Skeleton className="h-96 w-full rounded-2xl xl:col-span-5" />
      </div>
    </div>
  );
}
