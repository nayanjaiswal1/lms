import { Skeleton } from "@/components/ui/skeleton";

export default function RoleDetailLoading() {
  return (
    <div className="page-container space-y-4">
      <Skeleton className="h-8 w-48" />
      <Skeleton className="h-4 w-96" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}
