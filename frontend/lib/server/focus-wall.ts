import { apiGet } from "@/lib/server/api"

export type NoteColor = "yellow" | "blue" | "pink" | "green"
export type NoteCategory = "personal" | "study" | "urgent"

export interface FocusNote {
  id: string
  user_id: string
  text: string
  color: NoteColor
  category: NoteCategory
  position_x: number
  position_y: number
  rotation: number
  created_at: string
  updated_at: string
}

export async function getMyFocusNotes(): Promise<FocusNote[]> {
  return apiGet<FocusNote[]>("/api/focus-wall/notes")
}
