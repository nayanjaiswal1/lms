"use client"

import { useEffect, useRef, useState, useTransition } from "react"
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

function byPath(a: LabFileEntry, b: LabFileEntry): number {
  return a.path.localeCompare(b.path)
}

// Encapsulates all file-explorer/editor client state, including the
// VS Code-style multi-tab open-files list, so LabEnvironment and its panels
// stay under the 2-useState-per-component limit — this hook is the
// sanctioned place for the extra state, per frontend/CLAUDE.md.
export function useLabFiles(sessionId: string, autoLoad = false) {
  const [files, setFiles] = useState<LabFileEntry[]>([])
  const [openFiles, setOpenFiles] = useState<OpenFile[]>([])
  const [activePath, setActivePath] = useState<string | null>(null)
  const [validateResults, setValidateResults] = useState<Record<string, ValidateResult>>({})
  const [isLoading, startLoad] = useTransition()
  const [isSaving, startSave] = useTransition()

  // Web labs open on the file explorer, so the tree must populate without
  // waiting for a tab click. Runs once per session.
  const autoLoaded = useRef(false)
  useEffect(() => {
    if (!autoLoad || autoLoaded.current) return
    autoLoaded.current = true
    loadFiles()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- loadFiles is stable per sessionId; guarded to run once
  }, [autoLoad])

  function loadFiles() {
    startLoad(async () => {
      const res = await listLabFilesAction(sessionId)
      if (!res.ok || !res.data) {
        toast.error(res.error ?? "Failed to load files.")
        return
      }
      setFiles([...res.data].sort(byPath))
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

  // create/rename/delete apply their state changes optimistically (before the
  // server round trip) so the tree updates in one paint like VS Code instead
  // of flashing draft → old state → new state; on failure they roll back and
  // resync from the server via loadFiles().

  function createFile(path: string) {
    setFiles((prev) =>
      prev.some((f) => f.path === path) ? prev : [...prev, { path, type: "file" as const }].sort(byPath),
    )
    setOpenFiles((prev) =>
      prev.some((f) => f.path === path) ? prev : [...prev, { path, content: "", dirty: false }],
    )
    setActivePath(path)
    startSave(async () => {
      const res = await writeLabFileAction(sessionId, path, "")
      if (!res.ok) {
        toast.error(res.error ?? "Failed to create file.")
        setOpenFiles((prev) => prev.filter((f) => f.path !== path))
        setActivePath((prev) => (prev === path ? null : prev))
        loadFiles()
      }
    })
  }

  function createFolder(path: string) {
    setFiles((prev) =>
      prev.some((f) => f.path === path) ? prev : [...prev, { path, type: "dir" as const }].sort(byPath),
    )
    startSave(async () => {
      const res = await createLabDirectoryAction(sessionId, path)
      if (!res.ok) {
        toast.error(res.error ?? "Failed to create folder.")
        loadFiles()
      }
    })
  }

  function renameFile(from: string, to: string) {
    // Applies a→b to every piece of path-keyed state; called again with the
    // arguments swapped to roll back if the server rejects the rename.
    const apply = (a: string, b: string) => {
      const remap = (path: string) =>
        path === a ? b : path.startsWith(`${a}/`) ? b + path.slice(a.length) : path
      setFiles((prev) => prev.map((f) => ({ ...f, path: remap(f.path) })).sort(byPath))
      setOpenFiles((prev) => prev.map((f) => ({ ...f, path: remap(f.path) })))
      setActivePath((prev) => (prev ? remap(prev) : prev))
      setValidateResults((prev) =>
        Object.fromEntries(Object.entries(prev).map(([path, result]) => [remap(path), result])),
      )
    }

    apply(from, to)
    startSave(async () => {
      const res = await renameLabFileAction(sessionId, from, to)
      if (!res.ok) {
        toast.error(res.error ?? "Failed to rename file.")
        apply(to, from)
        loadFiles()
      }
    })
  }

  function deleteFile(path: string) {
    setFiles((prev) => prev.filter((f) => !isWithin(f.path, path)))
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
    startSave(async () => {
      const res = await deleteLabFileAction(sessionId, path)
      if (!res.ok) {
        toast.error(res.error ?? "Failed to delete file.")
        loadFiles()
      }
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
