import {
  BookOpenCheck,
  ListChecks,
  Megaphone,
  Rocket,
  ShieldCheck,
  Sparkles,
  Star,
  Zap,
  type LucideIcon,
} from "lucide-react";
import { WHATS_NEW_ICON } from "@/lib/constants";

export interface WhatsNewEntry {
  id: string;
  title: string;
  description: string;
  icon: string;
  cta_label: string;
  cta_href: string;
  published: boolean;
  published_at: string;
  updated_at: string;
}

// Maps a whats_new_entries.icon value (WHATS_NEW_ICON_OPTIONS, lib/constants.ts)
// to the lucide component that renders it in whats-new-dialog.tsx. Keyed by
// plain string, not WhatsNewIcon — the value arrives over the wire from the
// API response, not as a narrowed literal type.
export const WHATS_NEW_ICON_MAP: Record<string, LucideIcon | undefined> = {
  [WHATS_NEW_ICON.SPARKLES]: Sparkles,
  [WHATS_NEW_ICON.BOOK_OPEN_CHECK]: BookOpenCheck,
  [WHATS_NEW_ICON.LIST_CHECKS]: ListChecks,
  [WHATS_NEW_ICON.SHIELD_CHECK]: ShieldCheck,
  [WHATS_NEW_ICON.ROCKET]: Rocket,
  [WHATS_NEW_ICON.MEGAPHONE]: Megaphone,
  [WHATS_NEW_ICON.ZAP]: Zap,
  [WHATS_NEW_ICON.STAR]: Star,
};
