"use server"

import { apiAction } from "@/lib/server/api"
import type { ActionResult } from "@/lib/server/api"
import type { FocusNote, NoteColor, NoteCategory } from "@/lib/server/focus-wall"

interface CreatePayload {
  text: string
  color: NoteColor
  category: NoteCategory
  position_x: number
  position_y: number
  rotation: number
}

interface UpdatePayload {
  text?: string
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
