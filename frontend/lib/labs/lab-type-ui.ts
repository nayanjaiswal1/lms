import { Terminal, Code2, Beaker, BookOpen, Boxes, Bug, type LucideIcon } from "lucide-react"
import type { LabType } from "@/lib/labs"

export const LAB_TYPE_ICONS: Record<LabType, LucideIcon> = {
  terminal: Terminal,
  code: Code2,
  playground: Beaker,
  guided: BookOpen,
  sandbox: Boxes,
  debug: Bug,
}

export const LAB_TYPE_LABELS: Record<LabType, string> = {
  terminal: "Terminal",
  code: "Code",
  playground: "Playground",
  guided: "Guided",
  sandbox: "Sandbox",
  debug: "Debug",
}
