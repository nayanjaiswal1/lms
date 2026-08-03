"use server"

import { apiAction } from "@/lib/server/api"
import type { ActionResult } from "@/lib/server/api"
import type { FocusCategory, FocusNote, NoteColor } from "@/lib/server/focus-wall"

interface CreatePayload {
  text: string
  color: NoteColor
  category: string
  position_x: number
  position_y: number
  rotation: number
}

interface UpdatePayload {
  text?: string
  category?: string
  position_x?: number
  position_y?: number
  rotation?: number
}

export async function createNoteAction(payload: CreatePayload): Promise<ActionResult<FocusNote>> {
  return apiAction<FocusNote>("POST", "/api/focus-wall/notes", payload)
}

export async function updateNoteAction(
  noteId: string,
  payload: UpdatePayload,
): Promise<ActionResult<FocusNote>> {
  return apiAction<FocusNote>("PATCH", `/api/focus-wall/notes/${noteId}`, payload)
}

export async function deleteNoteAction(noteId: string): Promise<ActionResult<null>> {
  return apiAction<null>("DELETE", `/api/focus-wall/notes/${noteId}`)
}

export async function createCategoryAction(name: string): Promise<ActionResult<FocusCategory>> {
  return apiAction<FocusCategory>("POST", "/api/focus-wall/categories", { name })
}

export async function deleteCategoryAction(categoryId: string): Promise<ActionResult<null>> {
  return apiAction<null>("DELETE", `/api/focus-wall/categories/${categoryId}`)
}
