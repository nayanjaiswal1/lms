import { Skeleton } from "@/components/ui/skeleton";

export default function QuestionBankLoading() {
  return (
    <div className="page-container py-10">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-48" />
          <Skeleton className="h-4 w-64" />
        </div>
        <Skeleton className="h-10 w-36" />
      </div>
      <div className="table-responsive mt-8 flex flex-col gap-3">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton className="h-12" key={i} />
        ))}
      </div>
    </div>
  );
}
