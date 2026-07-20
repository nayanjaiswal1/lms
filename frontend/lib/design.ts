import type { ExcalidrawElement } from "@excalidraw/excalidraw/element/types";
import type { AppState, BinaryFiles } from "@excalidraw/excalidraw/types";

// Mirrors backend/internal/systemdesign/models.go Scene — round-tripped
// verbatim through the API, so the element/appState types come straight
// from Excalidraw rather than being redeclared here.
export interface DesignScene {
  elements: readonly ExcalidrawElement[];
  appState: Partial<AppState>;
  files?: BinaryFiles;
}

export interface DesignAttemptSummary {
  id: string;
  attempt_number: number;
  has_feedback: boolean;
  created_at: string;
  updated_at: string;
}

export interface DesignAttempt {
  id: string;
  module_id: string;
  user_id: string;
  attempt_number: number;
  scene: DesignScene;
  feedback?: string;
  feedback_at?: string;
  created_at: string;
  updated_at: string;
}

export interface DesignChatMessage {
  id: string;
  role: "user" | "assistant";
  content: string;
  created_at: string;
}

export const EMPTY_SCENE: DesignScene = { elements: [], appState: {} };
