import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ArrowLeft, ShieldAlert, ShieldCheck, Info, AlertTriangle } from "lucide-react";
import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { getAttemptProctoringLog } from "@/lib/server/assessments";
import type { ProctoringEvent } from "@/lib/server/assessments";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Proctoring Log",
};

interface PageProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ heartbeats?: string }>;
}

const EVENT_LABELS: Record<string, string> = {
  visibility_hidden: "Tab switch (hidden)",
  visibility_visible: "Tab returned",
  focus_loss: "Window focus lost",
  focus_gain: "Window focus returned",
  fullscreen_exit: "Exited fullscreen",
  fullscreen_enter: "Entered fullscreen",
  copy: "Copy attempt",
  cut: "Cut attempt",
  paste: "Paste attempt",
  right_click: "Right-click",
  devtools_open: "DevTools detected",
  heartbeat: "Heartbeat",
  network_offline: "Network offline",
};

function severityIcon(s: string) {
  if (s === "critical") return <ShieldAlert className="h-4 w-4 text-destructive" />;
  if (s === "warning") return <AlertTriangle className="h-4 w-4 text-primary" />;
  return <Info className="h-4 w-4 text-muted-foreground" />;
}

function severityBadge(s: string) {
  if (s === "critical") return <Badge variant="destructive">critical</Badge>;
  if (s === "warning") return <Badge variant="outline">warning</Badge>;
  return null;
}

function countBySeverity(events: ProctoringEvent[], severity: string) {
  return events.filter((e) => e.severity === severity).length;
}

export default async function ProctoringLogPage({ params, searchParams }: PageProps) {
  const { id } = await params;
  const { heartbeats } = await searchParams;
  const showHeartbeats = heartbeats === "1";

  let log: Awaited<ReturnType<typeof getAttemptProctoringLog>>;
  try {
    log = await getAttemptProctoringLog(id);
  } catch {
    notFound();
  }

  const { attempt, events } = log;
  const visible = showHeartbeats ? events : events.filter((e) => e.event_type !== "heartbeat");
  const critical = countBySeverity(events, "critical");
  const warnings = countBySeverity(events, "warning");
  const heartbeatCount = events.filter((e) => e.event_type === "heartbeat").length;

  const startedAt = attempt.started_at ? new Date(attempt.started_at) : null;

  return (
    <main className="page-container py-10">
      <Link
        className="mb-6 flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
        href={ROUTES.manageAssessmentResults(attempt.assessment_id)}
      >
        <ArrowLeft className="h-4 w-4" />
        Back to results
      </Link>

      <header className="mb-6">
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div>
            <h1 className="page-title">Proctoring Log</h1>
            <p className="text-muted-foreground">
              Attempt #{attempt.attempt_number} · {attempt.status}
            </p>
          </div>
          {attempt.percentage !== null && (
            <div className="text-right">
              <p className="text-3xl font-bold tabular-nums">{Math.round(attempt.percentage)}%</p>
              {attempt.passed !== null && (
                <Badge variant={attempt.passed ? "default" : "destructive"}>
                  {attempt.passed ? "Passed" : "Failed"}
                </Badge>
              )}
            </div>
          )}
        </div>
      </header>

      <section className="grid-stats grid gap-4 mb-10">
        <div className="card-base flex items-center gap-3 p-4">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-muted">
            <ShieldAlert className="h-5 w-5 text-destructive" />
          </span>
          <div>
            <p className="text-xs text-muted-foreground">Critical</p>
            <p className="text-lg font-semibold tabular-nums">{critical}</p>
          </div>
        </div>
        <div className="card-base flex items-center gap-3 p-4">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-muted">
            <AlertTriangle className="h-5 w-5 text-primary" />
          </span>
          <div>
            <p className="text-xs text-muted-foreground">Warnings</p>
            <p className="text-lg font-semibold tabular-nums">{warnings}</p>
          </div>
        </div>
        <div className="card-base flex items-center gap-3 p-4">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-muted">
            <ShieldCheck className="h-5 w-5 text-primary" />
          </span>
          <div>
            <p className="text-xs text-muted-foreground">Events total</p>
            <p className="text-lg font-semibold tabular-nums">{events.length}</p>
          </div>
        </div>
        <div className="card-base flex items-center gap-3 p-4">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-muted">
            <Info className="h-5 w-5 text-muted-foreground" />
          </span>
          <div>
            <p className="text-xs text-muted-foreground">Duration</p>
            <p className="text-lg font-semibold tabular-nums">
              {attempt.duration_seconds < 60
                ? `${attempt.duration_seconds}s`
                : `${Math.round(attempt.duration_seconds / 60)}m`}
            </p>
          </div>
        </div>
      </section>

      <section>
        <div className="mb-3 flex items-center justify-between gap-4">
          <h2 className="section-title">Event timeline</h2>
          {heartbeatCount > 0 && (
            <Link
              className="text-sm text-muted-foreground hover:text-foreground"
              href={showHeartbeats ? `?` : `?heartbeats=1`}
            >
              {showHeartbeats
                ? `Hide ${heartbeatCount} heartbeats`
                : `Show ${heartbeatCount} heartbeats`}
            </Link>
          )}
        </div>

        {visible.length === 0 ? (
          <p className="text-sm text-muted-foreground">No events recorded.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {visible.map((ev, i) => {
              const ts = new Date(ev.created_at);
              const elapsed =
                startedAt && !Number.isNaN(ts.getTime()) && !Number.isNaN(startedAt.getTime())
                  ? Math.round((ts.getTime() - startedAt.getTime()) / 1000)
                  : null;
              return (
                <div
                  className="card-base flex items-start gap-3 p-4"
                  key={`${ev.event_type}-${i}`}
                >
                  <span className="mt-0.5 shrink-0">{severityIcon(ev.severity)}</span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-sm font-medium">
                        {EVENT_LABELS[ev.event_type] ?? ev.event_type.replace(/_/g, " ")}
                      </span>
                      {severityBadge(ev.severity)}
                    </div>
                    {ev.metadata && Object.keys(ev.metadata).length > 0 && (
                      <p className="mt-0.5 text-xs text-muted-foreground">
                        {Object.entries(ev.metadata)
                          .map(([k, v]) => `${k}: ${String(v)}`)
                          .join(" · ")}
                      </p>
                    )}
                  </div>
                  <div className="shrink-0 text-right">
                    <p className="text-xs text-muted-foreground tabular-nums">
                      {ts.toLocaleTimeString()}
                    </p>
                    {elapsed !== null && (
                      <p className="text-xs text-muted-foreground tabular-nums">
                        +{elapsed}s
                      </p>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>
    </main>
  );
}
