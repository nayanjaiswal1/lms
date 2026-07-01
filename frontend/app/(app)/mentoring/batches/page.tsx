import { Suspense } from "react";
import Link from "next/link";
import { Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { getBatches } from "@/lib/server/batches";
import ROUTES from "@/lib/routes";

export const metadata = { title: "My Batches — MindForge" };

async function BatchList() {
  const batches = await getBatches();

  if (batches.length === 0) {
    return (
      <div className="empty-state py-16">
        <Users aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">You are not assigned to any batches yet.</p>
      </div>
    );
  }

  return (
    <ol className="flex flex-col gap-3" aria-label="Batches">
      {batches.map((batch) => (
        <li key={batch.id}>
          <Link href={ROUTES.mentoringBatch(batch.id)} className="card-interactive flex items-center gap-4 p-5">
            <div className="flex flex-1 flex-col gap-1">
              <div className="flex items-center gap-2">
                <span className="font-medium">{batch.name}</span>
                <Badge variant={batch.status === "active" ? "default" : "secondary"}>
                  {batch.status}
                </Badge>
              </div>
              {batch.description && (
                <p className="line-clamp-1 text-sm text-muted-foreground">{batch.description}</p>
              )}
              {batch.start_date && (
                <p className="text-xs text-muted-foreground">
                  {new Date(batch.start_date).toLocaleDateString()}
                  {batch.end_date && ` – ${new Date(batch.end_date).toLocaleDateString()}`}
                </p>
              )}
            </div>
          </Link>
        </li>
      ))}
    </ol>
  );
}

export default function MentorBatchesPage() {
  return (
    <main className="page-container py-8">
      <div className="page-header">
        <h1 className="page-title">My Batches</h1>
      </div>
      <Suspense fallback={<Skeleton className="h-64 rounded-lg" />}>
        <BatchList />
      </Suspense>
    </main>
  );
}
