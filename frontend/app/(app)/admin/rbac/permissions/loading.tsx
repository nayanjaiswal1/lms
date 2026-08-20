import { Skeleton } from "@/components/ui/skeleton";

export default function PermissionsLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-56" />
          <Skeleton className="h-4 w-96" />
        </div>
        <Skeleton className="h-6 w-28" />
      </div>

      <div className="mt-8 space-y-8">
        {Array.from({ length: 3 }).map((_, section) => (
          <div key={section}>
            <Skeleton className="mb-4 h-5 w-32" />
            <div className="flex flex-col gap-2">
              {Array.from({ length: 4 }).map((_, i) => (
                <Skeleton className="h-9 w-full" key={i} />
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
