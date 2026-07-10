"use client";

// Plan Day — root client component. Orchestrates the unscheduled backlog
// (ranked by plan_position) and the day timeline (tasks with a
// scheduled_start) via one reducer, mirroring calendar-grid.tsx's pattern
// rather than what-now-app.tsx's multiple useState calls.

import { useEffect, useReducer } from "react";
import { parseAsString, useQueryState } from "nuqs";
import { toast } from "sonner";
import {
  getDayPlanAction,
  getPlanInboxAction,
  reorderBacklogAction,
  scheduleTaskAction,
} from "@/lib/server/whatnow";
import type { DayPlan, PlanTask, SchedulePatch } from "@/lib/server/whatnow";
import { CaptureSheet } from "@/components/whatnow/capture-sheet";
import { PlanBacklog } from "@/components/whatnow/plan-backlog";
import { PlanTimeline } from "@/components/whatnow/plan-timeline";
import { addDays, isoDateParam } from "@/lib/whatnow/day-math";

interface ResizePreview {
  taskId: string;
  deltaMinutes: number;
}

interface PlanState {
  plan: DayPlan;
  inbox: PlanTask[];
  resizePreview: ResizePreview | null;
}

type PlanAction =
  | { type: "setPlan"; plan: DayPlan }
  | { type: "setInbox"; inbox: PlanTask[] }
  | { type: "applySchedule"; task: PlanTask }
  | { type: "reorderUnscheduled"; tasks: PlanTask[]; removeInboxId?: string }
  | { type: "startResize"; taskId: string }
  | { type: "updateResize"; deltaMinutes: number }
  | { type: "clearResize" };

function planReducer(state: PlanState, action: PlanAction): PlanState {
  switch (action.type) {
    case "setPlan":
      return { ...state, plan: action.plan };
    case "setInbox":
      return { ...state, inbox: action.inbox };
    case "applySchedule": {
      const { task } = action;
      const scheduled = state.plan.scheduled.filter((t) => t.id !== task.id);
      const unscheduled = state.plan.unscheduled.filter((t) => t.id !== task.id);
      const inbox = state.inbox.filter((t) => t.id !== task.id);
      if (task.scheduledStart && isoDateParam(new Date(task.scheduledStart)) === state.plan.date) {
        scheduled.push(task);
        scheduled.sort((a, b) => (a.scheduledStart ?? "").localeCompare(b.scheduledStart ?? ""));
      } else if (!task.scheduledStart) {
        unscheduled.push(task);
      }
      // else: scheduled for a different day — it belongs to that day's view, not this one.
      return { ...state, plan: { ...state.plan, scheduled, unscheduled }, inbox };
    }
    case "reorderUnscheduled": {
      const inbox = action.removeInboxId
        ? state.inbox.filter((t) => t.id !== action.removeInboxId)
        : state.inbox;
      return { ...state, plan: { ...state.plan, unscheduled: action.tasks }, inbox };
    }
    case "startResize":
      return { ...state, resizePreview: { taskId: action.taskId, deltaMinutes: 0 } };
    case "updateResize":
      return state.resizePreview
        ? { ...state, resizePreview: { ...state.resizePreview, deltaMinutes: action.deltaMinutes } }
        : state;
    case "clearResize":
      return { ...state, resizePreview: null };
    default:
      return state;
  }
}

interface PlanDayAppProps {
  initialDate: string;
  initialPlan: DayPlan;
  initialInbox: PlanTask[];
  initialError?: string;
}

export function PlanDayApp({ initialDate, initialPlan, initialInbox, initialError }: PlanDayAppProps) {
  const [date, setDate] = useQueryState("date", parseAsString.withDefault(initialDate));
  const [state, dispatch] = useReducer(planReducer, {
    plan: initialPlan,
    inbox: initialInbox,
    resizePreview: null,
  });

  useEffect(() => {
    if (initialError) toast.error(initialError);
  }, [initialError]);

  useEffect(() => {
    if (date === initialDate) return; // server already fetched this one
    let cancelled = false;
    void (async () => {
      const result = await getDayPlanAction(date);
      if (cancelled) return;
      if (!result.ok || !result.data) {
        toast.error(result.error ?? "Could not load the day plan.");
        return;
      }
      dispatch({ type: "setPlan", plan: result.data });
    })();
    return () => {
      cancelled = true;
    };
  }, [date, initialDate]);

  function navigate(direction: 1 | -1) {
    void setDate(isoDateParam(addDays(new Date(date), direction)));
  }

  async function refreshInbox() {
    const result = await getPlanInboxAction();
    if (result.ok) dispatch({ type: "setInbox", inbox: result.data ?? [] });
  }

  async function reorderUnscheduled(nextOrder: PlanTask[]) {
    const ids = [...nextOrder.map((t) => t.id), ...state.plan.scheduled.map((t) => t.id)];
    const result = await reorderBacklogAction(ids);
    if (!result.ok) {
      toast.error(result.error ?? "Could not reorder the backlog.");
      return;
    }
    dispatch({ type: "reorderUnscheduled", tasks: nextOrder });
  }

  async function planInboxTask(task: PlanTask) {
    const allPlannedIds = [...state.plan.unscheduled, ...state.plan.scheduled].map((t) => t.id);
    const result = await reorderBacklogAction([...allPlannedIds, task.id]);
    if (!result.ok) {
      toast.error(result.error ?? "Could not add that to the plan.");
      return;
    }
    dispatch({
      type: "reorderUnscheduled",
      tasks: [...state.plan.unscheduled, { ...task, status: "planned" }],
      removeInboxId: task.id,
    });
  }

  async function scheduleTask(taskId: string, patch: SchedulePatch) {
    const result = await scheduleTaskAction(taskId, patch);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not update the schedule.");
      return;
    }
    dispatch({ type: "applySchedule", task: result.data });
  }

  return (
    <div className="stack-lg items-start">
      <div className="flex w-full flex-col gap-4 sm:w-72 sm:shrink-0">
        <PlanBacklog
          inbox={state.inbox}
          tasks={state.plan.unscheduled}
          onPlanInboxTask={(task) => void planInboxTask(task)}
          onReorder={(next) => void reorderUnscheduled(next)}
          onUnschedule={(taskId) => void scheduleTask(taskId, { scheduledStart: null })}
        />
        <CaptureSheet onCaptured={() => void refreshInbox()} />
      </div>
      <PlanTimeline
        date={date}
        resizePreview={state.resizePreview}
        tasks={state.plan.scheduled}
        onNavigate={navigate}
        onResizeEnd={() => dispatch({ type: "clearResize" })}
        onResizeMove={(deltaMinutes) => dispatch({ type: "updateResize", deltaMinutes })}
        onResizeStart={(taskId) => dispatch({ type: "startResize", taskId })}
        onSchedule={(taskId, patch) => void scheduleTask(taskId, patch)}
      />
    </div>
  );
}
