import { Skeleton } from "@/components/ui/skeleton";

export default function InterestsLoading() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-10 w-80" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}
