import { Suspense } from "react";
import Link from "next/link";
import { MessageSquare } from "lucide-react";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { getBatches } from "@/lib/server/batches";
import { getBatchMessages, type BatchMessage } from "@/lib/server/messaging";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Messages — MindForge" };

interface BatchThread {
  batchId: string;
  batchName: string;
  latest: BatchMessage | null;
  unresolvedCount: number;
}

async function loadThreads(): Promise<BatchThread[]> {
  const batches = await getBatches();

  const threads = await Promise.all(
    batches.map(async (batch) => {
      const [recent, unresolved] = await Promise.all([
        getBatchMessages(batch.id, { limit: 1 }).catch(() => []),
        getBatchMessages(batch.id, { type: "question", unresolved: true, limit: 50 }).catch(() => []),
      ]);
      return {
        batchId: batch.id,
        batchName: batch.name,
        latest: recent[0] ?? null,
        unresolvedCount: unresolved.length,
      };
    }),
  );

  return threads.sort((a, b) => {
    if (!a.latest && !b.latest) return 0;
    if (!a.latest) return 1;
    if (!b.latest) return -1;
    return new Date(b.latest.created_at).getTime() - new Date(a.latest.created_at).getTime();
  });
}

async function MessageThreads() {
  const threads = await loadThreads();

  if (threads.length === 0) {
    return (
      <div className="empty-state py-16">
        <MessageSquare aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">You are not assigned to any batches yet.</p>
      </div>
    );
  }

  return (
    <ol className="flex flex-col gap-3" aria-label="Batch message threads">
      {threads.map((t) => (
        <li key={t.batchId}>
          <Link
            href={ROUTES.mentoringBatchChat(t.batchId)}
            className="card-interactive flex items-start gap-4 p-5"
          >
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10">
              <MessageSquare aria-hidden className="h-5 w-5 text-primary" />
            </span>
            <div className="min-w-0 flex-1 flex flex-col gap-1">
              <div className="flex items-center gap-2">
                <span className="font-medium">{t.batchName}</span>
                {t.unresolvedCount > 0 && (
                  <Badge className="badge-info text-xs px-1.5 py-0 h-4" variant="outline">
                    {t.unresolvedCount} open
                  </Badge>
                )}
              </div>
              {t.latest ? (
                <p className="truncate text-sm text-muted-foreground">
                  <span className="font-medium text-foreground">{t.latest.sender_name}:</span> {t.latest.body}
                </p>
              ) : (
                <p className="text-sm text-muted-foreground">No messages yet.</p>
              )}
            </div>
            {t.latest && (
              <span className="shrink-0 text-xs text-muted-foreground">
                {new Date(t.latest.created_at).toLocaleDateString()}
              </span>
            )}
          </Link>
        </li>
      ))}
    </ol>
  );
}

export default function MentorMessagesPage() {
  return (
    <main className="page-container py-8">
      <div className="page-header">
        <h1 className="page-title">Messages</h1>
      </div>
      <Suspense fallback={<Skeleton className="h-64 rounded-lg" />}>
        <MessageThreads />
      </Suspense>
    </main>
  );
}
