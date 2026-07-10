"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Terminal, Clock, CheckSquare, Loader2, LogOut } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { LabReadinessWait } from "@/components/labs/lab-readiness-wait";
import { LabTimer } from "@/components/labs/lab-timer";
import { LabWorkspaceContent, isLabAuthError } from "@/components/labs/lab-workspace-content";
import { startLabSessionAction, endLabSessionAction } from "@/app/(app)/labs/[labId]/actions";
import { useLabProvisioning } from "@/lib/labs/provisioning-context";
import { isLabSessionAlreadyEnded, type GetSessionResponse, type Lab } from "@/lib/labs";
import ROUTES from "@/lib/routes";

interface ModuleLabClientProps {
  lab: Lab;
  title: string;
  initialSession: GetSessionResponse | null;
}

// Inline course-page counterpart to LabEnvironment/LabStartButton — same
// start/end calls, but renders in place instead of navigating to
// /labs/sessions/[sessionId]. router.refresh() re-runs the server-side
// ModuleLab fetch (lab + active session), so provisioning->running and
// end->overview transitions just fall out of a fresh server render.
export function ModuleLabClient({ lab, title, initialSession }: ModuleLabClientProps) {
  const router = useRouter();
  const { session: activeSession, track, clear } = useLabProvisioning();
  const [isStarting, startStarting] = useTransition();
  const [isEnding, startEnding] = useTransition();

  const isOtherLabActive = activeSession !== null && activeSession.lab_id !== lab.id;

  const handleStart = () => {
    if (isOtherLabActive) {
      toast.error(`${activeSession.lab_title} is still running`, {
        description: "End it to start this lab instead — you can only run one lab at a time.",
      });
      return;
    }

    startStarting(async () => {
      const result = await startLabSessionAction(lab.id, crypto.randomUUID());
      if (result.error || !result.data) {
        toast.error(result.error ?? "Failed to start lab session.");
        return;
      }
      track({
        session_id: result.data.id,
        lab_id: lab.id,
        lab_title: lab.title,
        lab_type: lab.lab_type,
        status: result.data.status,
        started_at: result.data.started_at,
        expires_at: result.data.expires_at,
        last_active_at: result.data.last_active_at,
      });
      router.refresh();
    });
  };

  const handleEnd = () => {
    if (!initialSession) return;
    const sessionId = initialSession.session.id;
    startEnding(async () => {
      const res = await endLabSessionAction(sessionId);
      if (!res.ok && !isLabSessionAlreadyEnded(res.error ?? "")) {
        const msg = res.error ?? "Failed to end lab. Please try again.";
        if (isLabAuthError(msg)) {
          router.push(ROUTES.LOGIN);
          return;
        }
        toast.error(msg);
        return;
      }
      clear(sessionId);
      router.refresh();
    });
  };

  if (initialSession?.session.status === "provisioning") {
    return (
      <LabReadinessWait
        sessionId={initialSession.session.id}
        onFailed={() => router.refresh()}
        onReady={() => router.refresh()}
      />
    );
  }

  if (
    initialSession &&
    (initialSession.session.status === "running" || initialSession.session.status === "paused")
  ) {
    // Console-layout labs flow the task checklist inline with the rest of
    // the notes and pin the terminal to the bottom of the viewport instead
    // (see LabFixedConsole) — they don't need a bounded box of their own.
    const isConsoleLayout = lab.layout === "console";
    return (
      <div
        className={cn(
          "flex flex-col rounded-lg border border-border bg-card",
          isConsoleLayout ? "min-h-[50dvh]" : "h-[70dvh] overflow-hidden lg:h-[80dvh]",
        )}
      >
        <header className="flex h-12 shrink-0 items-center justify-between gap-3 border-b border-border px-4">
          <span className="truncate text-sm font-semibold text-foreground">{lab.title}</span>
          <div className="flex shrink-0 items-center gap-3">
            <LabTimer expiresAt={initialSession.session.expires_at} onExpired={handleEnd} />
            <Button disabled={isEnding} size="sm" variant="outline" onClick={handleEnd}>
              <LogOut aria-hidden className="h-3.5 w-3.5" />
              {isEnding ? "Ending…" : "End Lab"}
            </Button>
          </div>
        </header>
        <LabWorkspaceContent
          consoleMode={isConsoleLayout ? "fixed" : "boxed"}
          initialCompletions={initialSession.task_completions}
          lab={lab}
          session={initialSession.session}
          onLogin={() => router.push(ROUTES.LOGIN)}
        />
      </div>
    );
  }

  const totalPoints = lab.tasks.reduce((s, t) => s + t.points, 0);
  const requiredCount = lab.tasks.filter((t) => !t.is_optional).length;

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <Badge className="capitalize" variant="outline">{lab.lab_type}</Badge>
          <Badge variant="secondary">
            <Clock aria-hidden className="mr-1 h-3 w-3" />{lab.max_duration} min
          </Badge>
          <Badge variant="secondary">
            <CheckSquare aria-hidden className="mr-1 h-3 w-3" />{lab.tasks.length} tasks
          </Badge>
          {totalPoints > 0 && <Badge variant="secondary">{totalPoints} pts</Badge>}
        </div>
        <h1 className="text-2xl font-bold tracking-tight">{title}</h1>
        {lab.description && (
          <p className="leading-relaxed text-muted-foreground">{lab.description}</p>
        )}
      </header>

      {lab.tasks.length > 0 && (
        <ol className="flex flex-col gap-2">
          {lab.tasks.map((task) => (
            <li className="card-base flex items-start gap-3 p-4" key={task.task_id}>
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-semibold text-muted-foreground">
                {task.position}
              </span>
              <div className="flex min-w-0 flex-col gap-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="text-sm font-medium">{task.title}</span>
                  {task.is_optional && (
                    <Badge className="text-xs" variant="outline">optional</Badge>
                  )}
                  {task.points > 0 && (
                    <Badge className="text-xs" variant="secondary">{task.points} pts</Badge>
                  )}
                </div>
                <p className="text-xs text-muted-foreground">{task.description}</p>
              </div>
            </li>
          ))}
        </ol>
      )}

      <div className="flex flex-col gap-2">
        <p className="text-sm text-muted-foreground">
          {requiredCount} required task{requiredCount !== 1 ? "s" : ""} ·{" "}
          up to {lab.max_resets} reset{lab.max_resets !== 1 ? "s" : ""} ·{" "}
          {lab.max_duration} min time limit
        </p>
        <Button
          className="w-full sm:w-auto"
          disabled={isStarting}
          size="lg"
          onClick={handleStart}
        >
          {isStarting ? (
            <Loader2 aria-hidden className="mr-2 h-4 w-4 animate-spin" />
          ) : (
            <Terminal aria-hidden className="mr-2 h-4 w-4" />
          )}
          {isStarting ? "Starting…" : isOtherLabActive ? "Another lab is active" : "Launch Lab"}
        </Button>
      </div>
    </div>
  );
}
