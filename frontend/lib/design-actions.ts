"use server";

import { apiAction, type ActionResult } from "@/lib/server/api";
import type { DesignAttempt, DesignChatMessage, DesignScene } from "@/lib/design";

export async function createDesignAttemptAction(moduleId: string): Promise<ActionResult<DesignAttempt>> {
  return apiAction<DesignAttempt>("POST", `/api/modules/${moduleId}/design/attempts`);
}

export async function getDesignAttemptAction(
  moduleId: string,
  attemptId: string,
): Promise<ActionResult<DesignAttempt>> {
  return apiAction<DesignAttempt>("GET", `/api/modules/${moduleId}/design/attempts/${attemptId}`);
}

export async function saveDesignSceneAction(
  moduleId: string,
  attemptId: string,
  scene: DesignScene,
): Promise<ActionResult<DesignAttempt>> {
  return apiAction<DesignAttempt>("PUT", `/api/modules/${moduleId}/design/attempts/${attemptId}/scene`, { scene });
}

export async function getDesignFeedbackAction(
  moduleId: string,
  attemptId: string,
): Promise<ActionResult<{ feedback: string; feedback_at: string }>> {
  return apiAction("POST", `/api/modules/${moduleId}/design/attempts/${attemptId}/feedback`);
}

export async function sendDesignChatMessageAction(
  moduleId: string,
  content: string,
): Promise<ActionResult<DesignChatMessage[]>> {
  return apiAction<DesignChatMessage[]>("POST", `/api/modules/${moduleId}/design/chat`, { content });
}
