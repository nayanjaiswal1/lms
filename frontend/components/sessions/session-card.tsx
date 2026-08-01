import Link from "next/link";
import { Clock } from "lucide-react";
import { SessionStatusBadge } from "@/components/sessions/session-status-badge";
import type { MentorSession } from "@/lib/server/sessions";
import { formatSessionRange } from "@/lib/sessions/format";
import ROUTES from "@/lib/routes";

interface SessionCardProps {
  session: MentorSession;
  viewerIsMentor: boolean;
}

export function SessionCard({ session, viewerIsMentor }: SessionCardProps) {
  const counterpart = viewerIsMentor
    ? (session.student_name ?? session.batch_name ?? "Student")
    : (session.mentor_name ?? "Mentor");

  return (
    <Link className="card-interactive flex flex-col gap-3 p-6" href={ROUTES.session(session.id)}>
      <div className="flex items-start justify-between gap-3">
        <h3 className="min-w-0 truncate font-semibold text-foreground">{session.title}</h3>
        <SessionStatusBadge status={session.status} />
      </div>
      <p className="min-w-0 truncate text-sm text-muted-foreground">{counterpart}</p>
      <div className="flex items-center gap-1.5 text-sm text-muted-foreground">
        <Clock aria-hidden className="h-4 w-4 shrink-0" />
        <span>{formatSessionRange(session.starts_at, session.ends_at)}</span>
      </div>
    </Link>
  );
}
