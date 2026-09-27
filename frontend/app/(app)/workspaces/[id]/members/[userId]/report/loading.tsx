import { Skeleton } from "@/components/ui/skeleton";

export default function MemberReportLoading() {
  return (
    <div className="flex flex-col gap-6">
      <Skeleton className="h-10 w-full sm:w-1/3" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}
