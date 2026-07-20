import "server-only";
import { apiGet } from "@/lib/server/api";
import type { DesignAttempt, DesignAttemptSummary, DesignChatMessage } from "@/lib/design";

/**
 * The caller's attempts for a system_design module (may be empty — the
 * student hasn't started yet) plus the full scene for whichever attempt
 * should be shown first: the one named by `attemptId` if given and valid,
 * otherwise the most recently updated one.
 */
export async function getModuleDesign(
  moduleId: string,
  attemptId?: string,
): Promise<{ attempts: DesignAttemptSummary[]; selected: DesignAttempt | null; chat: DesignChatMessage[] } | null> {
  let attempts: DesignAttemptSummary[];
  let chat: DesignChatMessage[];
  try {
    [attempts, chat] = await Promise.all([
      apiGet<DesignAttemptSummary[]>(`/api/modules/${moduleId}/design/attempts`),
      apiGet<DesignChatMessage[]>(`/api/modules/${moduleId}/design/chat`),
    ]);
  } catch {
    return null;
  }

  const targetId = attemptId && attempts.some((a) => a.id === attemptId)
    ? attemptId
    : attempts[attempts.length - 1]?.id;

  const selected = targetId
    ? await apiGet<DesignAttempt>(`/api/modules/${moduleId}/design/attempts/${targetId}`).catch(() => null)
    : null;

  return { attempts, selected, chat };
}
