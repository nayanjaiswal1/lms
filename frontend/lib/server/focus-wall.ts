import { apiGet } from "@/lib/server/api"

export type NoteColor = "yellow" | "blue" | "pink" | "green"

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
