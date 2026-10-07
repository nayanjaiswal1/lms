import { Skeleton } from "@/components/ui/skeleton";

export default function RecipeBuilderLoading() {
  return (
    <main className="page-container flex flex-col gap-4">
      <Skeleton className="h-5 w-32" />
      <Skeleton className="h-9 w-72" />
      <Skeleton className="h-11 w-full" />
      <Skeleton className="h-11 w-full" />
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-32 w-full" key={i} />
        ))}
      </div>
    </main>
  );
}
