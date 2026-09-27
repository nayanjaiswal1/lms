import { Skeleton } from "@/components/ui/skeleton";

export default function ListLoading() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-10 w-full sm:w-2/3" />
      <Skeleton className="h-96 w-full" />
    </div>
  );
}
