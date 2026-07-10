// The ONE data-access file for What Now?. Every request goes through here.
// If the real backend endpoints differ, edit only this file.
//
// Auth: mindforge uses httpOnly cookie sessions (access_token + csrf_token),
// not a browser-readable bearer token — so requests go same-origin through
// the /api/whatnow proxy route, which forwards cookies to the backend.

import type {
  BreakdownProposal,
  CompleteResponse,
  Energy,
  NowResponse,
  PlanToday,
  StuckReason,
  StuckResolution,
  Task,
  TaskPatch,
  WeeklyRecap,
} from "@/lib/whatnow/types";

/** Single config value for the API base. */
export const WHATNOW_API_BASE = "/api/whatnow";

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

function csrfToken(): string {
  return (
    document.cookie
      .split("; ")
      .find((c) => c.startsWith("csrf_token="))
      ?.slice("csrf_token=".length) ?? ""
  );
}

async function request<T>(
  method: "GET" | "POST" | "PATCH" | "PUT",
  path: string,
  body?: unknown,
): Promise<T> {
  const res = await fetch(`${WHATNOW_API_BASE}${path}`, {
    method,
    credentials: "same-origin",
    headers: {
      "X-CSRF-Token": csrfToken(),
      ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    let message = `Request failed (${res.status})`;
    try {
      const data = (await res.json()) as { error?: string; message?: string };
      message = data.error ?? data.message ?? message;
    } catch {
      /* non-JSON error body — keep the default message */
    }
    throw new ApiError(res.status, message);
  }
  if (res.status === 204) return undefined as T;
  const payload = (await res.json()) as { data?: T } | T;
  // backend convention wraps responses in { data } — unwrap when present
  return payload !== null &&
    typeof payload === "object" &&
    "data" in (payload as Record<string, unknown>)
    ? (payload as { data: T }).data
    : (payload as T);
}

export const whatnowApi = {
  // capture
  captureTask: (raw: string) => request<Task>("POST", "/tasks", { raw }),

  // now
  getNow: (energy: Energy, availableMin?: number) =>
    request<NowResponse>(
      "GET",
      `/tasks/now?energy=${energy}${availableMin ? `&availableMin=${availableMin}` : ""}`,
    ),

  // inbox / edits
  getInbox: () => request<Task[]>("GET", "/tasks/inbox"),
  patchTask: (id: string, patch: TaskPatch) =>
    request<Task>("PATCH", `/tasks/${id}`, patch),

  // focus lifecycle
  completeTask: (id: string) =>
    request<CompleteResponse>("POST", `/tasks/${id}/complete`),
  pauseTask: (id: string, resumeNote: string) =>
    request<Task>("POST", `/tasks/${id}/pause`, { resumeNote }),
  stuckTask: (id: string, reason: StuckReason) =>
    request<StuckResolution>("POST", `/tasks/${id}/stuck`, { reason }),

  // breakdown
  proposeBreakdown: (id: string) =>
    request<BreakdownProposal>("POST", `/tasks/${id}/breakdown`),
  confirmBreakdown: (id: string, proposal: BreakdownProposal) =>
    request<Task[]>("POST", `/tasks/${id}/breakdown/confirm`, proposal),

  // plan
  getPlanToday: () => request<PlanToday>("GET", "/plan/today"),
  postPlanToday: (taskIds: string[]) =>
    request<PlanToday>("POST", "/plan/today", { taskIds }),

  // archive / amnesty
  getDecayed: () => request<Task[]>("GET", "/archive/decayed"),
  reviveTask: (id: string) => request<Task>("POST", `/tasks/${id}/revive`),
  getWeeklyRecap: () => request<WeeklyRecap>("GET", "/recap/weekly"),

  // energy
  putEnergy: (energy: Energy) => request<void>("PUT", "/me/energy", { energy }),
};
