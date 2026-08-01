import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { getFeatureConfig } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getBookingConfig } from "@/lib/server/sessions";
import { getMentors } from "@/lib/server/mentoring";
import { BookSessionDialog } from "@/components/sessions/book-session-dialog";

interface Props {
  batchId: string;
}

/**
 * The batch-level entry point into session booking. Batch scheduling is
 * permission-gated server-side (POST /api/batches/{id}/sessions sits behind
 * mentoring.manage_session_booking), so this renders nothing at all for
 * someone who couldn't complete the action anyway — no lock overlay, since
 * a student viewing their own batch shouldn't be told the control exists.
 */
export async function ScheduleBatchSession({ batchId }: Props) {
  const { orgFeatures } = await getFeatureConfig();
  if (!orgFeatures.includes(FEATURES.SESSION_BOOKING)) return null;

  const perms = await getMyPermissions();
  if (!perms.includes(PERMISSIONS.MENTORING.MANAGE_SESSION_BOOKING)) return null;

  // Either read failing is not worth taking the whole batch page down for —
  // without a mentor list there is nobody to schedule against, so the button
  // simply doesn't render.
  const [config, mentors] = await Promise.all([
    getBookingConfig().catch(() => null),
    getMentors().catch(() => []),
  ]);
  if (mentors.length === 0) return null;

  return (
    <BookSessionDialog
      balance={0}
      batchId={batchId}
      defaultDurationMinutes={config?.config.default_duration_minutes ?? 30}
      mentors={mentors.map((m) => ({ value: m.user_id, label: m.name }))}
      requireCredits={false}
      triggerLabel="Schedule session"
    />
  );
}
