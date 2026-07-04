import { PlayCircle, FileText, ClipboardCheck, Terminal, type LucideIcon } from "lucide-react";

export const MODULE_TYPE_ICON: Record<string, LucideIcon> = {
  video: PlayCircle,
  pdf: FileText,
  notes: FileText,
  assessment: ClipboardCheck,
  lab: Terminal,
};

export const MODULE_TYPE_LABEL: Record<string, string> = {
  video: "Video",
  pdf: "PDF",
  notes: "Reading",
  assessment: "Assessment",
  lab: "Lab",
};
