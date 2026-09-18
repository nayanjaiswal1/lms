import "server-only";

import { apiGet } from "@/lib/server/api";

export type CaptureType = "image" | "pdf" | "link" | "html";
export type CaptureStatus = "pending" | "processing" | "ready" | "failed" | "promoted" | "dismissed";
export type CaptureKind = "note" | "question";

export interface Capture {
  id: string;
  user_id: string;
  type: CaptureType;
  storage_key?: string;
  source_url?: string;
  status: CaptureStatus;
  extracted_text?: string;
  kind?: CaptureKind;
  category?: string;
  subcategory?: string;
  title?: string;
  content?: string;
  journal_entry_id?: string;
  srs_card_id?: string;
  error_message?: string;
  created_at: string;
  processed_at?: string;
}

export interface SimilarMatch {
  type: "journal_entry" | "srs_card";
  id: string;
  title: string;
}

export interface CaptureDetail {
  capture: Capture;
  similar_entries: SimilarMatch[];
}

export interface PromoteCaptureInput {
  category?: string;
  subcategory?: string;
  title?: string;
  content?: string;
  merge_into_id?: string;
}

export async function getCaptures(status?: CaptureStatus): Promise<Capture[]> {
  const query = status ? `?status=${encodeURIComponent(status)}` : "";
  return apiGet<Capture[]>(`/api/captures${query}`);
}
