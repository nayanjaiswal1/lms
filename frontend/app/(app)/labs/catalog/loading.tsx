import { Skeleton } from "@/components/ui/skeleton"

export default function LabCatalogLoading() {
  return (
    <main className="page-container flex flex-col gap-6">
      <header className="flex flex-col gap-2">
        <Skeleton className="h-8 w-56" />
        <Skeleton className="h-4 w-full max-w-lg" />
      </header>
      <div className="flex flex-col gap-3 sm:flex-row">
        {Array.from({ length: 3 }).map((_, i) => (
          <Skeleton className="h-10 w-full sm:w-44" key={i} />
        ))}
      </div>
      <div className="flex flex-col gap-4">
        <Skeleton className="h-6 w-64" />
        <div className="grid-responsive">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton className="h-32 w-full" key={i} />
          ))}
        </div>
      </div>
    </main>
  )
}
