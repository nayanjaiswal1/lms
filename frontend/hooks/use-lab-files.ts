"use client"

import { useState, useTransition } from "react"
import { toast } from "sonner"
import {
  listLabFilesAction,
  readLabFileAction,
  writeLabFileAction,
  createLabDirectoryAction,
  renameLabFileAction,
  deleteLabFileAction,
  validateLabFileAction,
} from "@/app/(app)/labs/sessions/[sessionId]/files-actions"
import type { LabFileEntry, ValidateResult } from "@/lib/labs/files"

interface OpenFile {
  path: string
  content: string
  dirty: boolean
}

// True when `path` is exactly `underPath` or nested under it — used so a
// folder rename/delete also remaps or closes every open tab inside it.
function isWithin(path: string, underPath: string): boolean {
  return path === underPath || path.startsWith(`${underPath}/`)
}

// Encapsulates all file-explorer/editor client state, including the
// VS Code-style multi-tab open-files list, so LabEnvironment and its panels
// stay under the 2-useState-per-component limit — this hook is the
// sanctioned place for the extra state, per frontend/CLAUDE.md.
export function useLabFiles(sessionId: string) {
  const [files, setFiles] = useState<LabFileEntry[]>([])
  const [openFiles, setOpenFiles] = useState<OpenFile[]>([])
  const [activePath, setActivePath] = useState<string | null>(null)
  const [validateResults, setValidateResults] = useState<Record<string, ValidateResult>>({})
  const [isLoading, startLoad] = useTransition()
  const [isSaving, startSave] = useTransition()

  function loadFiles() {
    startLoad(async () => {
      const res = await listLabFilesAction(sessionId)
      if (!res.ok || !res.data) {
        toast.error(res.error ?? "Failed to load files.")
        return
      }
      setFiles([...res.data].sort((a, b) => a.path.localeCompare(b.path)))
    })
  }

  function openFile(path: string) {
    if (openFiles.some((f) => f.path === path)) {
      setActivePath(path)
      return
    }
    startLoad(async () => {
      const res = await readLabFileAction(sessionId, path)
      if (!res.ok || !res.data) {
        toast.error(res.error ?? "Failed to read file.")
        return
      }
      const content = res.data.content
      setOpenFiles((prev) => [...prev, { path, content, dirty: false }])
      setActivePath(path)
    })
  }

  function closeFile(path: string) {
    setOpenFiles((prev) => {
      const index = prev.findIndex((f) => f.path === path)
      if (index === -1) return prev
      const next = prev.filter((f) => f.path !== path)
      if (activePath === path) {
        const fallback = next[index - 1] ?? next[0] ?? null
        setActivePath(fallback ? fallback.path : null)
      }
      return next
    })
    setValidateResults((prev) => {
      if (!(path in prev)) return prev
      const { [path]: _removed, ...rest } = prev
      return rest
    })
  }

  function updateContent(content: string) {
    if (!activePath) return
    setOpenFiles((prev) =>
      prev.map((f) => (f.path === activePath ? { ...f, content, dirty: true } : f)),
    )
  }

  function save() {
    if (!activePath) return
    const file = openFiles.find((f) => f.path === activePath)
    if (!file) return
    startSave(async () => {
      const res = await writeLabFileAction(sessionId, file.path, file.content)
      if (!res.ok) {
        toast.error(res.error ?? "Failed to save file.")
        return
      }
      toast.success("Saved")
      setOpenFiles((prev) => prev.map((f) => (f.path === file.path ? { ...f, dirty: false } : f)))
    })
  }

  function validate() {
    if (!activePath) return
    const path = activePath
    startSave(async () => {
      const res = await validateLabFileAction(sessionId, path)
      if (!res.ok || !res.data) {
        toast.error(res.error ?? "Validation failed.")
        return
      }
      setValidateResults((prev) => ({ ...prev, [path]: res.data as ValidateResult }))
      if (res.data.valid) toast.success("Manifest is valid")
    })
  }

  function createFile(path: string) {
    startSave(async () => {
      const res = await writeLabFileAction(sessionId, path, "")
      if (!res.ok) {
        toast.error(res.error ?? "Failed to create file.")
        return
      }
      loadFiles()
      openFile(path)
    })
  }

  function createFolder(path: string) {
    startSave(async () => {
      const res = await createLabDirectoryAction(sessionId, path)
      if (!res.ok) {
        toast.error(res.error ?? "Failed to create folder.")
        return
      }
      loadFiles()
    })
  }

  function renameFile(from: string, to: string) {
    startSave(async () => {
      const res = await renameLabFileAction(sessionId, from, to)
      if (!res.ok) {
        toast.error(res.error ?? "Failed to rename file.")
        return
      }
      loadFiles()

      const remap = (path: string) =>
        path === from ? to : path.startsWith(`${from}/`) ? to + path.slice(from.length) : path

      setOpenFiles((prev) => prev.map((f) => ({ ...f, path: remap(f.path) })))
      if (activePath && isWithin(activePath, from)) setActivePath(remap(activePath))
      setValidateResults((prev) => {
        let changed = false
        const next: Record<string, ValidateResult> = {}
        for (const [path, result] of Object.entries(prev)) {
          const remapped = remap(path)
          if (remapped !== path) changed = true
          next[remapped] = result
        }
        return changed ? next : prev
      })
    })
  }

  function deleteFile(path: string) {
    startSave(async () => {
      const res = await deleteLabFileAction(sessionId, path)
      if (!res.ok) {
        toast.error(res.error ?? "Failed to delete file.")
        return
      }
      loadFiles()

      setOpenFiles((prev) => {
        const removedIndex = prev.findIndex((f) => isWithin(f.path, path))
        const next = prev.filter((f) => !isWithin(f.path, path))
        if (activePath && isWithin(activePath, path)) {
          const fallback = next[removedIndex - 1] ?? next[0] ?? null
          setActivePath(fallback ? fallback.path : null)
        }
        return next
      })
      setValidateResults((prev) => {
        let changed = false
        const next: Record<string, ValidateResult> = {}
        for (const [entryPath, result] of Object.entries(prev)) {
          if (isWithin(entryPath, path)) {
            changed = true
            continue
          }
          next[entryPath] = result
        }
        return changed ? next : prev
      })
    })
  }

  return {
    files,
    openFiles,
    activePath,
    validateResult: activePath ? (validateResults[activePath] ?? null) : null,
    isLoading,
    isSaving,
    loadFiles,
    openFile,
    closeFile,
    updateContent,
    save,
    validate,
    createFile,
    createFolder,
    renameFile,
    deleteFile,
  }
}
