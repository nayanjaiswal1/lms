import { Skeleton } from "@/components/ui/skeleton";

export default function AuditLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <Skeleton className="h-8 w-32" />
      </div>

      <div className="mt-8 table-responsive">
        <div className="flex flex-col gap-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton className="h-10 w-full" key={i} />
          ))}
        </div>
      </div>
    </div>
  );
}
