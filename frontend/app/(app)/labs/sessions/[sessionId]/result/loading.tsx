import { Skeleton } from "@/components/ui/skeleton";

export default function LabResultLoading() {
  return (
    <main className="page-container flex max-w-4xl flex-col gap-6">
      <Skeleton className="h-20 w-full" />
      <Skeleton className="h-48 w-full" />
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Skeleton className="h-48 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    </main>
  );
}
