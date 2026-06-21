import { Suspense } from "react";
import Link from "next/link";
import { Brain, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { getPracticeSessions } from "@/lib/server/practice";
import ROUTES from "@/lib/routes";

export const metadata = { title: "AI Practice — MindForge" };

const STATUS_BADGE: Record<string, string> = {
  active:    "bg-primary text-primary-foreground",
  completed: "bg-muted text-muted-foreground",
  abandoned: "border border-border text-muted-foreground",
};

async function SessionList() {
  const sessions = await getPracticeSessions();

  if (sessions.length === 0) {
    return (
      <div className="empty-state py-16">
        <Brain aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">No practice sessions yet. Start one to prepare for interviews.</p>
        <Button asChild className="mt-4">
          <Link href={ROUTES.PRACTICE_NEW}>Start your first session</Link>
        </Button>
      </div>
    );
  }

  return (
    <ol className="flex flex-col gap-3" aria-label="Practice sessions">
      {sessions.map((session) => (
        <li key={session.id}>
          <Link
            href={ROUTES.practiceSession(session.id)}
            className="card-interactive flex items-center gap-4 p-4"
          >
            <div className="flex flex-1 flex-col gap-1">
              <div className="flex items-center gap-2">
                <span className="font-medium capitalize">{session.technology}</span>
                <Badge className={STATUS_BADGE[session.status] ?? ""} variant="outline">
                  {session.status}
                </Badge>
              </div>
              <div className="flex gap-3 text-xs text-muted-foreground">
                <span className="capitalize">{session.difficulty}</span>
                <span>{session.question_count} questions</span>
                <span>{new Date(session.created_at).toLocaleDateString()}</span>
              </div>
            </div>
          </Link>
        </li>
      ))}
    </ol>
  );
}

export default function PracticePage() {
  return (
    <main className="page-container py-8">
      <div className="page-header">
        <h1 className="page-title">AI Practice</h1>
        <Button asChild>
          <Link href={ROUTES.PRACTICE_NEW}>
            <Plus aria-hidden className="mr-2 h-4 w-4" />
            New session
          </Link>
        </Button>
      </div>
      <Suspense fallback={<Skeleton className="h-64 rounded-lg" />}>
        <SessionList />
      </Suspense>
    </main>
  );
}
