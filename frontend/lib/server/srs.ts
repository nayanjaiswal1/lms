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

interface DueCardsResponse {
  cards: SRSCard[];
  total: number;
}

async function getCards(path: string): Promise<DueCardsResponse> {
  const data = await apiGet<DueCardsResponse>(path);
  return { cards: data.cards ?? [], total: data.total ?? 0 };
}

export function getDueCards(): Promise<DueCardsResponse> {
  return getCards("/api/srs/due");
}

// Today's due cards ranked weakest-first (overdue + repeated lapses), capped.
export function getDrillCards(): Promise<DueCardsResponse> {
  return getCards("/api/srs/drill");
}
