import { apiGet } from "@/lib/server/api"

export type NoteColor = "yellow" | "blue" | "pink" | "green"
// Built-ins only — a note's actual category is any string the user has
// created via FocusCategory, so the wider type is `string` at the API
// boundary (see FocusNote.category below).
export type NoteCategory = "personal" | "study" | "urgent"

export interface FocusNote {
  id: string
  user_id: string
  text: string
  color: NoteColor
  category: string
  position_x: number
  position_y: number
  rotation: number
  created_at: string
  updated_at: string
}

export interface FocusCategory {
  id: string
  user_id: string
  name: string
  created_at: string
}

export async function getMyFocusNotes(): Promise<FocusNote[]> {
  return apiGet<FocusNote[]>("/api/focus-wall/notes")
}

export async function getMyFocusCategories(): Promise<FocusCategory[]> {
  return apiGet<FocusCategory[]>("/api/focus-wall/categories")
}
