import { File, FileCode, FileJson, FileTerminal, FileText, Folder, FolderOpen, type LucideIcon } from "lucide-react"

// VS Code-style per-extension icon lookup for the lab file explorer/tabs.
// Kept monochrome (callers apply text-muted-foreground/text-primary) since
// raw color classes are banned outside globals.css tokens.
export function getFileIcon(path: string, type: "file" | "dir", isExpanded?: boolean): LucideIcon {
  if (type === "dir") return isExpanded ? FolderOpen : Folder

  const dot = path.lastIndexOf(".")
  const ext = dot === -1 ? "" : path.slice(dot + 1).toLowerCase()

  switch (ext) {
    case "json":
      return FileJson
    case "sh":
    case "bash":
      return FileTerminal
    case "yaml":
    case "yml":
      return FileCode
    case "md":
      return FileText
    default:
      return File
  }
}
