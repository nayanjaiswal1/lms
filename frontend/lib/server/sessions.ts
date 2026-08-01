"use server";

import { revalidatePath } from "next/cache";
import { apiGet, apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

// ─────────────────────────────────────────────
// Session booking wire-contract types — mirrors /api/session-booking/* and
// /api/mentor-sessions/* in backend/internal/sessions.
//
// Declared here rather than in lib/sessions/types.ts for the same reason
// lib/server/calendar.ts declares its own: this is a shared-lib module and
// the boundaries lint only lets shared-lib depend on shared-lib. They are
// type-only exports, so Next's "every value export in a 'use server' module
// must be an async function" rule does not apply — types are erased before
// it runs.
//
// Never `export type { ActionResult }` from this file (see CLAUDE.md): a
// type-only re-export leaves a dangling server reference at runtime.
// ─────────────────────────────────────────────

export type SessionStatus = "scheduled" | "completed" | "cancelled" | "no_show";
export type FeedbackAuthorRole = "student" | "mentor";
export type SessionScope = "upcoming" | "past" | "all";
export type LedgerReason =
  | "purchase"
  | "admin_grant"
  | "admin_revoke"
  | "booking"
  | "cancellation_refund";

export interface BookingConfig {
  org_id: string;
  enabled: boolean;
  require_credits: boolean;
  cancel_cutoff_hours: number;
  min_notice_hours: number;
  booking_horizon_days: number;
  max_upcoming_per_student: number;
  default_duration_minutes: number;
  updated_at: string;
}

export interface AvailabilityRule {
  id: string;
  org_id: string;
  mentor_id: string;
  /** 0 = Sunday … 6 = Saturday, matching Go's time.Weekday. */
  weekday: number;
  /** Minutes from local midnight in `timezone`. */
  start_minute: number;
  end_minute: number;
  slot_minutes: number;
  timezone: string;
  active: boolean;
}

export interface AvailabilityException {
  id: string;
  mentor_id: string;
  /** YYYY-MM-DD, interpreted in `timezone`. */
  on_date: string;
  start_minute: number | null;
  end_minute: number | null;
  is_blocked: boolean;
  slot_minutes: number;
  timezone: string;
  note: string | null;
}

/**
 * One window on a mentor's grid. Taken slots are returned, not filtered —
 * the UI renders them as busy so a mentor's day reads as a real schedule
 * rather than one with unexplained gaps.
 */
export interface Slot {
  starts_at: string;
  ends_at: string;
  taken: boolean;
}

export interface MentorSession {
  id: string;
  org_id: string;
  mentor_id: string;
  student_id: string | null;
  batch_id: string | null;
  title: string;
  agenda: string | null;
  starts_at: string;
  ends_at: string;
  status: SessionStatus;
  booked_by: string;
  meeting_url: string | null;
  calendar_event_id: string | null;
  cancelled_by: string | null;
  cancelled_at: string | null;
  cancel_reason: string | null;
  completed_at: string | null;
  mentor_name?: string;
  student_name?: string;
  batch_name?: string;
}

export interface SessionFeedback {
  id: string;
  session_id: string;
  author_id: string;
  author_role: FeedbackAuthorRole;
  rating: number;
  comment: string | null;
  author_name?: string;
  created_at: string;
}

export interface SessionNotes {
  session_id: string;
  mentor_id: string;
  body: string;
  visible_to_student: boolean;
  updated_at: string;
}

export interface SessionDetail {
  session: MentorSession;
  feedback: SessionFeedback[];
  /** Null when there are no notes, or when they are private and the caller is the student. */
  notes: SessionNotes | null;
  /** The caller's own rating, so the form renders as an edit rather than inviting a duplicate. */
  my_feedback: SessionFeedback | null;
}

export interface CreditPack {
  id: string;
  org_id: string;
  name: string;
  description: string | null;
  sessions: number;
  /** In PAYMENTS_CURRENCY minor units. For an INR deployment these are paise — never divide by 100 blindly, format via the payments config. */
  price_cents: number;
  currency: string;
  active: boolean;
}

export interface LedgerEntry {
  id: string;
  delta: number;
  reason: LedgerReason;
  session_id: string | null;
  note: string | null;
  created_at: string;
}

export interface CreditSummary {
  balance: number;
  entries: LedgerEntry[];
}

/** What a cancellation actually did, so the UI states the outcome rather than guessing. */
export interface CancelResult {
  session: MentorSession;
  credit_refunded: boolean;
  within_cutoff: boolean;
  cutoff_hours: number;
  already_closed: boolean;
}

export interface PackCheckout {
  purchase_id: string;
  provider: string;
  status: string;
  redirect_url?: string;
  client_params?: Record<string, string>;
  amount_cents: number;
  currency: string;
}

export interface BookSessionInput {
  mentor_id: string;
  /** Omit when the caller is the student booking for themselves. */
  student_id?: string;
  title?: string;
  agenda?: string;
  meeting_url?: string;
  starts_at: string;
  ends_at: string;
}

export interface MenteeProgress {
  student_id: string;
  student_name: string | null;
  total_sessions: number;
  completed_count: number;
  cancelled_count: number;
  no_show_count: number;
  first_session_at: string | null;
  last_session_at: string | null;
  avg_rating_given: number | null;
  upcoming_session: MentorSession | null;
  sessions: MentorSession[];
}

// ─────────────────────────────────────────────
// Reads — throw on error, handled by error.tsx
// ─────────────────────────────────────────────

/** The org's booking policy plus the caller's own balance, in one round trip. */
export async function getBookingConfig(): Promise<{ config: BookingConfig; balance: number }> {
  return apiGet<{ config: BookingConfig; balance: number }>("/api/session-booking/config");
}

export async function listSessions(scope: SessionScope = "all"): Promise<MentorSession[]> {
  const { sessions } = await apiGet<{ sessions: MentorSession[] }>(
    `/api/mentor-sessions?scope=${scope}`,
  );
  return sessions;
}

export async function getSessionDetail(id: string): Promise<SessionDetail> {
  return apiGet<SessionDetail>(`/api/mentor-sessions/${id}`);
}

export async function getMyAvailability(): Promise<{
  rules: AvailabilityRule[];
  exceptions: AvailabilityException[];
}> {
  return apiGet<{ rules: AvailabilityRule[]; exceptions: AvailabilityException[] }>(
    "/api/session-booking/availability/me",
  );
}

export async function getCredits(): Promise<CreditSummary> {
  return apiGet<CreditSummary>("/api/session-booking/credits");
}

export async function listPacks(includeArchived = false): Promise<CreditPack[]> {
  const { packs } = await apiGet<{ packs: CreditPack[] }>(
    `/api/session-booking/packs${includeArchived ? "?all=true" : ""}`,
  );
  return packs;
}

export async function getMenteeProgress(studentId: string): Promise<MenteeProgress> {
  return apiGet<MenteeProgress>(`/api/session-booking/mentees/${studentId}`);
}

// ─────────────────────────────────────────────
// Actions — return ActionResult, never throw
// ─────────────────────────────────────────────

/**
 * Slots are fetched through an action rather than apiGet because the booking
 * dialog refetches them as the user pages between days, and a failure there
 * must render inline ("couldn't load times") instead of throwing the whole
 * page into error.tsx.
 */
export async function getMentorSlotsAction(
  mentorId: string,
  from: string,
  to: string,
): Promise<ActionResult<{ slots: Slot[] }>> {
  return apiAction<{ slots: Slot[] }>(
    "GET",
    `/api/mentors/${mentorId}/slots?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`,
  );
}

export async function bookSessionAction(
  payload: BookSessionInput,
): Promise<ActionResult<MentorSession>> {
  const result = await apiAction<MentorSession>("POST", "/api/mentor-sessions", payload);
  if (result.ok) {
    revalidatePath(ROUTES.SESSIONS);
    revalidatePath(ROUTES.CALENDAR);
  }
  return result;
}

export async function bookBatchSessionAction(
  batchId: string,
  payload: Omit<BookSessionInput, "student_id">,
): Promise<ActionResult<MentorSession>> {
  const result = await apiAction<MentorSession>("POST", `/api/batches/${batchId}/sessions`, payload);
  if (result.ok) {
    revalidatePath(ROUTES.SESSIONS);
    revalidatePath(ROUTES.CALENDAR);
  }
  return result;
}

export async function cancelSessionAction(
  id: string,
  reason: string,
): Promise<ActionResult<CancelResult>> {
  const result = await apiAction<CancelResult>("POST", `/api/mentor-sessions/${id}/cancel`, {
    reason,
  });
  if (result.ok) {
    revalidatePath(ROUTES.SESSIONS);
    revalidatePath(ROUTES.CALENDAR);
  }
  return result;
}

export async function rescheduleSessionAction(
  id: string,
  startsAt: string,
  endsAt: string,
): Promise<ActionResult<MentorSession>> {
  const result = await apiAction<MentorSession>("POST", `/api/mentor-sessions/${id}/reschedule`, {
    starts_at: startsAt,
    ends_at: endsAt,
  });
  if (result.ok) {
    revalidatePath(ROUTES.SESSIONS);
    revalidatePath(ROUTES.CALENDAR);
  }
  return result;
}

/** Mentor-only: close a session out as attended or a no-show. */
export async function setSessionOutcomeAction(
  id: string,
  status: Extract<SessionStatus, "completed" | "no_show">,
): Promise<ActionResult<MentorSession>> {
  const result = await apiAction<MentorSession>("POST", `/api/mentor-sessions/${id}/outcome`, {
    status,
  });
  if (result.ok) revalidatePath(ROUTES.SESSIONS);
  return result;
}

export async function submitSessionFeedbackAction(
  id: string,
  rating: number,
  comment: string,
): Promise<ActionResult<SessionFeedback>> {
  const result = await apiAction<SessionFeedback>("POST", `/api/mentor-sessions/${id}/feedback`, {
    rating,
    comment,
  });
  if (result.ok) revalidatePath(ROUTES.SESSIONS);
  return result;
}

/** Mentor-only: the write-up of what happened, private unless explicitly shared. */
export async function saveSessionNotesAction(
  id: string,
  body: string,
  visibleToStudent: boolean,
): Promise<ActionResult<SessionNotes>> {
  const result = await apiAction<SessionNotes>("PUT", `/api/mentor-sessions/${id}/notes`, {
    body,
    visible_to_student: visibleToStudent,
  });
  if (result.ok) revalidatePath(ROUTES.SESSIONS);
  return result;
}

export async function saveAvailabilityAction(
  rules: Omit<AvailabilityRule, "id" | "org_id" | "mentor_id">[],
): Promise<ActionResult<{ rules: AvailabilityRule[] }>> {
  const result = await apiAction<{ rules: AvailabilityRule[] }>(
    "PUT",
    "/api/session-booking/availability/me",
    { rules },
  );
  if (result.ok) revalidatePath(ROUTES.SESSION_AVAILABILITY);
  return result;
}

export async function addAvailabilityExceptionAction(payload: {
  on_date: string;
  start_minute: number | null;
  end_minute: number | null;
  is_blocked: boolean;
  slot_minutes: number;
  timezone: string;
  note?: string;
}): Promise<ActionResult<AvailabilityException>> {
  const result = await apiAction<AvailabilityException>(
    "POST",
    "/api/session-booking/availability/me/exceptions",
    payload,
  );
  if (result.ok) revalidatePath(ROUTES.SESSION_AVAILABILITY);
  return result;
}

export async function deleteAvailabilityExceptionAction(
  id: string,
): Promise<ActionResult<null>> {
  const result = await apiAction<null>(
    "DELETE",
    `/api/session-booking/availability/me/exceptions/${id}`,
  );
  if (result.ok) revalidatePath(ROUTES.SESSION_AVAILABILITY);
  return result;
}

export async function buyCreditPackAction(
  packId: string,
  provider: string,
): Promise<ActionResult<PackCheckout>> {
  const result = await apiAction<PackCheckout>(
    "POST",
    `/api/session-booking/packs/${packId}/checkout`,
    { provider },
  );
  if (result.ok) revalidatePath(ROUTES.SESSION_CREDITS);
  return result;
}

// ─── admin surface (mentoring.manage_session_booking) ─────────────────────

export async function updateBookingConfigAction(
  payload: Partial<BookingConfig>,
): Promise<ActionResult<BookingConfig>> {
  const result = await apiAction<BookingConfig>("PATCH", "/api/session-booking/config", payload);
  if (result.ok) {
    revalidatePath(ROUTES.SESSION_BOOKING_SETTINGS);
    revalidatePath(ROUTES.SESSIONS);
  }
  return result;
}

export async function saveCreditPackAction(payload: {
  id?: string;
  name: string;
  description?: string;
  sessions: number;
  price_cents: number;
  active: boolean;
}): Promise<ActionResult<CreditPack>> {
  const { id, ...body } = payload;
  const result = id
    ? await apiAction<CreditPack>("PATCH", `/api/session-booking/packs/${id}`, body)
    : await apiAction<CreditPack>("POST", "/api/session-booking/packs", body);
  if (result.ok) {
    revalidatePath(ROUTES.SESSION_BOOKING_SETTINGS);
    revalidatePath(ROUTES.SESSION_CREDITS);
  }
  return result;
}

export async function grantSessionCreditsAction(
  userId: string,
  delta: number,
  note: string,
): Promise<ActionResult<{ balance: number }>> {
  const result = await apiAction<{ balance: number }>(
    "POST",
    "/api/session-booking/credits/grant",
    { user_id: userId, delta, note },
  );
  if (result.ok) revalidatePath(ROUTES.SESSION_BOOKING_SETTINGS);
  return result;
}
