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
import { apiFetch } from "@/lib/client/api";

/** Single config value for the API base (suffix appended to /api by apiFetch). */
export const WHATNOW_API_BASE = "/whatnow";

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

async function request<T>(
  method: "GET" | "POST" | "PATCH" | "PUT",
  path: string,
  body?: unknown,
): Promise<T> {
  // Same-origin through the /api/whatnow proxy route (which forwards cookies
  // to the backend) via the shared apiFetch helper — credentials:include and
  // the X-CSRF-Token double-submit header are handled there, not here.
  const data = await apiFetch<T>(`${WHATNOW_API_BASE}${path}`, {
    method,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (data === null || data === undefined) {
    throw new ApiError(0, "Request failed. Check your connection and try again.");
  }
  return data;
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
  putEnergy: (energy: Energy) => request<null>("PUT", "/me/energy", { energy }),
};
