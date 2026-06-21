import "server-only";

import { apiGet } from "@/lib/server/api";

export interface SRSCard {
  id: string;
  user_id: string;
  question_id: string;
  front: string;
  back: string;
  source_type: string;
  interval_days: number;
  repetitions: number;
  ease_factor: number;
  due_date: string;
  last_reviewed_at: string | null;
  created_at: string;
}

export interface DueCardsResponse {
  cards: SRSCard[];
  total: number;
}

export async function getDueCards(): Promise<DueCardsResponse> {
  const data = await apiGet<DueCardsResponse>("/api/srs/due");
  return { cards: data.cards ?? [], total: data.total ?? 0 };
}
