import {
  Bike,
  BookOpen,
  Brain,
  Briefcase,
  Coffee,
  Dumbbell,
  Droplet,
  Flower2,
  Footprints,
  GraduationCap,
  Heart,
  Leaf,
  Moon,
  Music,
  Palette,
  PenTool,
  PhoneOff,
  PiggyBank,
  Smile,
  Sun,
  Target,
  UtensilsCrossed,
  Users,
  Code2,
  type LucideIcon,
} from "lucide-react";

// Curated icon set a habit's icon may be set to — keys must match
// backend/internal/habit/models.go's IconOptions and the habits_icon_check
// DB constraint exactly. "" (no entry here) means "no override."
// Partial (not Record<string, LucideIcon>) so indexing with an arbitrary
// icon string — most are typed emoji, not a curated key — correctly types
// as possibly-undefined instead of TS assuming every string key exists.
export const HABIT_ICONS: Partial<Record<string, LucideIcon>> = {
  dumbbell: Dumbbell,
  moon: Moon,
  "book-open": BookOpen,
  brain: Brain,
  droplet: Droplet,
  utensils: UtensilsCrossed,
  flower: Flower2,
  footprints: Footprints,
  "phone-off": PhoneOff,
  heart: Heart,
  music: Music,
  palette: Palette,
  code: Code2,
  "piggy-bank": PiggyBank,
  leaf: Leaf,
  sun: Sun,
  coffee: Coffee,
  "pen-tool": PenTool,
  target: Target,
  users: Users,
  briefcase: Briefcase,
  "graduation-cap": GraduationCap,
  bike: Bike,
  smile: Smile,
};

// Every entry of the literal object above is actually defined — Partial only
// matters for indexing with an arbitrary (non-curated) string below.
export const HABIT_ICON_OPTIONS = Object.entries(HABIT_ICONS).map(([value, Icon]) => ({ value, Icon: Icon as LucideIcon }));

// Soft UI cap on a typed-emoji icon — generous enough for a ZWJ family
// sequence (multiple code points) without allowing someone to paste a
// paragraph in. Backend's rune-count cap (8) is the authoritative limit;
// this just keeps the input from looking broken before that round-trip.
export const MAX_CUSTOM_ICON_LENGTH = 16;

export type ResolvedHabitIcon = { kind: "lucide"; Icon: LucideIcon } | { kind: "emoji"; value: string };

// Looks up a habit's chosen override icon: a curated lucide component, a
// typed emoji (any value that isn't a curated key), or null if there's no
// override ("") — callers fall back to their own type/cadence-based default
// icon in that case, so a habit created before this feature renders exactly
// as it did before.
export function customHabitIcon(icon: string): ResolvedHabitIcon | null {
  if (!icon) return null;
  const Icon = HABIT_ICONS[icon];
  return Icon ? { kind: "lucide", Icon } : { kind: "emoji", value: icon };
}
