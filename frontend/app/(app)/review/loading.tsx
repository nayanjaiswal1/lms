import { Skeleton } from "@/components/ui/skeleton";

export default function ReviewLoading() {
  return (
    <main className="page-container-sm flex flex-col items-center gap-6 py-10">
      <Skeleton className="h-8 w-40" />
      <Skeleton className="h-72 w-full max-w-lg rounded-lg" />
    </main>
  );
}
