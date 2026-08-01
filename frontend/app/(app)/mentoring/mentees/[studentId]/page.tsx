import { CalendarClock, CheckCircle2, Star, UserX, XCircle } from "lucide-react";
import { StatCard } from "@/components/shared/stat-card";
import { SessionCard } from "@/components/sessions/session-card";
import { getMenteeProgress } from "@/lib/server/sessions";

export const metadata = { title: "Mentee Progress — MindForge" };

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

interface MenteeProgressPageProps {
  params: Promise<{ studentId: string }>;
}

/** What a mentor opens before a session, to see where this mentee stands. */
export default async function MenteeProgressPage({ params }: MenteeProgressPageProps) {
  const { studentId } = await params;
  const progress = await getMenteeProgress(studentId);

  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <h1 className="page-title">{progress.student_name ?? "Mentee"}</h1>
        <p className="text-muted-foreground">
          What this mentee has done so far — open this before your next session together.
        </p>
      </div>

      <div className="grid-stats mb-6">
        <StatCard icon={CalendarClock} label="Total sessions" unit="all time" value={String(progress.total_sessions)} />
        <StatCard icon={CheckCircle2} label="Completed" unit="sessions" value={String(progress.completed_count)} />
        <StatCard icon={XCircle} label="Cancelled" unit="sessions" value={String(progress.cancelled_count)} />
        <StatCard icon={UserX} label="No-shows" unit="sessions" value={String(progress.no_show_count)} />
      </div>

      <div className="mb-8 grid gap-3 sm:grid-cols-2">
        <div className="card-base flex flex-col gap-1 p-5">
          <p className="text-xs text-muted-foreground">First session</p>
          <p className="font-medium">{formatDate(progress.first_session_at)}</p>
        </div>
        <div className="card-base flex flex-col gap-1 p-5">
          <p className="text-xs text-muted-foreground">Last session</p>
          <p className="font-medium">{formatDate(progress.last_session_at)}</p>
        </div>
      </div>

      {progress.avg_rating_given !== null && (
        <div className="card-base mb-8 flex items-center gap-3 p-5">
          <Star aria-hidden className="h-5 w-5 text-primary" />
          <div>
            <p className="text-sm text-muted-foreground">Average rating given</p>
            <p className="font-medium">{progress.avg_rating_given.toFixed(1)} / 5</p>
          </div>
        </div>
      )}

      {progress.upcoming_session && (
        <section className="mb-8 flex flex-col gap-3">
          <h2 className="section-title">Next session</h2>
          <div className="card-raised rounded-lg border-l-4 border-l-primary p-1">
            <SessionCard viewerIsMentor session={progress.upcoming_session} />
          </div>
        </section>
      )}

      <section className="flex flex-col gap-3">
        <h2 className="section-title">Session history</h2>
        {progress.sessions.length === 0 ? (
          <div className="empty-state py-12">
            <p className="text-sm text-muted-foreground">No sessions with this mentee yet.</p>
          </div>
        ) : (
          <ul className="flex flex-col gap-3">
            {progress.sessions.map((session) => (
              <li key={session.id}>
                <SessionCard viewerIsMentor session={session} />
              </li>
            ))}
          </ul>
        )}
      </section>
    </main>
  );
}
