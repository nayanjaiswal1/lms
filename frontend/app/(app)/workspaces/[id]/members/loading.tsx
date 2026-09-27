import { Skeleton } from "@/components/ui/skeleton";

export default function MembersLoading() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-10 w-40 self-end" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}
