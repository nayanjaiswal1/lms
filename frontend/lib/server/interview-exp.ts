import "server-only";

import { apiGet } from "@/lib/server/api";

export interface Post {
  id: string;
  author_id: string;
  company: string;
  position: string;
  tags: string[];
  title: string;
  created_at: string;
  updated_at: string;
}

export interface Entry {
  id: string;
  post_id: string;
  author_id: string;
  round_label: string;
  content: string;
  created_at: string;
  updated_at: string;
}

export interface Comment {
  id: string;
  qna_id: string;
  parent_id: string | null;
  author_id: string;
  content: string;
  deleted: boolean;
  created_at: string;
  updated_at: string;
  score: number;
  my_vote: number;
  replies: Comment[];
}

export interface Qna {
  id: string;
  post_id: string;
  entry_id: string | null;
  author_id: string;
  question: string;
  answer: string | null;
  created_at: string;
  updated_at: string;
  score: number;
  my_vote: number;
}

export interface QnaWithComments extends Qna {
  comments: Comment[];
}

export interface EntryWithQna extends Entry {
  qna: QnaWithComments[];
}

export interface PostDetail extends Post {
  entries: EntryWithQna[];
  standalone_qna: QnaWithComments[];
}

export interface ListFilter {
  company?: string;
  position?: string;
  tag?: string;
  q?: string;
}

export interface CreatePostInput {
  company: string;
  position: string;
  tags: string[];
  title: string;
}

export async function listPosts(filter: ListFilter): Promise<Post[]> {
  const params = new URLSearchParams();
  if (filter.company) params.set("company", filter.company);
  if (filter.position) params.set("position", filter.position);
  if (filter.tag) params.set("tag", filter.tag);
  if (filter.q) params.set("q", filter.q);
  const qs = params.toString();
  return apiGet<Post[]>(`/api/interview-exp/posts${qs ? `?${qs}` : ""}`);
}

export async function getPostDetail(id: string): Promise<PostDetail> {
  return apiGet<PostDetail>(`/api/interview-exp/posts/${encodeURIComponent(id)}`);
}

// ─── FAQ ──────────────────────────────────────────────────────────────────────

export type FaqStatus = "todo" | "done" | "revisit";

export interface FaqItem {
  qna_id: string;
  post_id: string;
  question: string;
  answer: string | null;
  company: string;
  position: string;
  tags: string[];
  score: number;
  status: FaqStatus;
  is_starred: boolean;
  created_at: string;
}

export interface FaqFilter {
  company?: string;
  tag?: string;
  status?: FaqStatus;
}

export async function listFaq(filter: FaqFilter): Promise<FaqItem[]> {
  const params = new URLSearchParams();
  if (filter.company) params.set("company", filter.company);
  if (filter.tag) params.set("tag", filter.tag);
  if (filter.status) params.set("status", filter.status);
  const qs = params.toString();
  return apiGet<FaqItem[]>(`/api/interview-exp/faq${qs ? `?${qs}` : ""}`);
}
