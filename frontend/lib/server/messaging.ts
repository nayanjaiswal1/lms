import "server-only";

import { apiGet } from "@/lib/server/api";

export interface BatchMessage {
  id: string;
  batch_id: string;
  sender_id: string;
  sender_name: string;
  parent_id: string | null;
  body: string;
  type: "question" | "answer" | "announcement" | "resource";
  is_pinned: boolean;
  is_resolved: boolean;
  edited_at: string | null;
  created_at: string;
  reactions: Array<{ reaction: string; count: number; user_reacted: boolean }>;
  reply_count: number;
}

export interface CourseFAQ {
  id: string;
  course_id: string;
  question: string;
  answer: string;
  ai_generated: boolean;
  position: number;
  created_at: string;
}

export interface GetBatchMessagesOptions {
  before?: string;
  limit?: number;
  type?: string;
  unresolved?: boolean;
  pinned?: boolean;
}

export async function getBatchMessages(batchID: string, opts: GetBatchMessagesOptions = {}): Promise<BatchMessage[]> {
  const params = new URLSearchParams();
  if (opts.before) params.set("before", opts.before);
  if (opts.limit) params.set("limit", String(opts.limit));
  if (opts.type) params.set("type", opts.type);
  if (opts.unresolved) params.set("unresolved", "true");
  if (opts.pinned) params.set("pinned", "true");
  const qs = params.toString();
  const data = await apiGet<{ messages: BatchMessage[] }>(`/api/batches/${batchID}/messages${qs ? `?${qs}` : ""}`);
  return data.messages ?? [];
}

export async function getCourseFAQs(courseID: string): Promise<CourseFAQ[]> {
  const data = await apiGet<{ faqs: CourseFAQ[] }>(`/api/courses/${courseID}/faqs`);
  return data.faqs ?? [];
}
