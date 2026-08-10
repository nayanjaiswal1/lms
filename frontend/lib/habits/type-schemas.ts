import { BookOpen, Dumbbell, ListChecks, Moon, Sparkles } from "lucide-react";
import { z } from "zod";
import type { CustomField, Habit, HabitType } from "@/lib/server/habits";

// Single source of truth for the habit-type system: which types exist, what
// their entry form looks like, and how to build a zod schema for it. Used by
// both the create-habit type picker (add-habit-inline.tsx) and the dynamic
// entry form rendered below the grid (habit-entry-form.tsx) — mirrors the
// backend's builtinMetadataFields in internal/habit/service.go, so a field
// added here must be added there too.
export type FieldKind = "text" | "number" | "textarea" | "time" | "slider";

export interface FieldDef {
  key: string;
  label: string;
  kind: FieldKind;
  placeholder?: string;
}

export const HABIT_TYPE_OPTIONS: { label: string; value: HabitType; icon: typeof Dumbbell }[] = [
  { label: "Generic (just a check-off)", value: "generic", icon: ListChecks },
  { label: "Gym", value: "gym", icon: Dumbbell },
  { label: "Sleep", value: "sleep", icon: Moon },
  { label: "Reading", value: "reading", icon: BookOpen },
  { label: "Custom", value: "custom", icon: Sparkles },
];

export const HABIT_TYPE_ICON: Record<HabitType, typeof Dumbbell> = {
  generic: ListChecks,
  gym: Dumbbell,
  sleep: Moon,
  reading: BookOpen,
  custom: Sparkles,
};

// Built-in field sets — keys must match backend's builtinMetadataFields.
const BUILTIN_FIELDS: Partial<Record<HabitType, FieldDef[]>> = {
  gym: [
    { key: "workout_type", label: "Workout Type", kind: "text", placeholder: "e.g., Strength, Cardio, Yoga" },
    { key: "exercise", label: "Exercise Name", kind: "text", placeholder: "e.g., Deadlift, Squat" },
    { key: "sets", label: "Sets", kind: "number" },
    { key: "duration_minutes", label: "Duration (mins)", kind: "number" },
    { key: "intensity", label: "Intensity (1-5)", kind: "number" },
    { key: "notes", label: "Performance Notes", kind: "textarea", placeholder: "Felt strong today..." },
  ],
  sleep: [
    { key: "slept_at", label: "Slept At", kind: "time" },
    { key: "woke_up", label: "Woke Up", kind: "time" },
    { key: "quality", label: "Quality (0-10)", kind: "slider" },
  ],
  reading: [
    { key: "book", label: "Book / Topic", kind: "text", placeholder: "Title" },
    { key: "pages", label: "Pages Read", kind: "number" },
    { key: "takeaway", label: "Key Takeaway", kind: "textarea", placeholder: "Focus on systems rather than goals." },
  ],
};

// A custom habit's fields come from the habit itself (user-defined at
// creation), everything else from the fixed BUILTIN_FIELDS map above.
// Generic habits have no fields — fieldsForHabit returns [].
export function fieldsForHabit(habit: Pick<Habit, "type" | "custom_fields">): FieldDef[] {
  if (habit.type === "custom") {
    return habit.custom_fields.map((f) => ({ key: f.key, label: f.label, kind: f.kind }));
  }
  return BUILTIN_FIELDS[habit.type] ?? [];
}

export function hasEntryForm(habit: Pick<Habit, "type" | "custom_fields">): boolean {
  return fieldsForHabit(habit).length > 0;
}

// Every field is optional — a day's journal entry can be filled in partially,
// same as the mockup (some fields pre-filled, others blank).
// A blank number/slider input preprocesses to undefined (field omitted from
// the saved entry) rather than coercing "" -> 0, which would silently record
// "0 sets"/"0 quality" for a field the user never touched.
function zodForKind(kind: FieldKind) {
  const blankToUndefined = (v: unknown) => (v === "" || v === undefined ? undefined : v);
  switch (kind) {
    case "number":
      return z.preprocess(blankToUndefined, z.coerce.number().optional());
    case "slider":
      return z.preprocess(blankToUndefined, z.coerce.number().min(0).max(10).optional());
    default:
      return z.string().optional();
  }
}

export function schemaForFields(fields: FieldDef[]) {
  const shape: Record<string, ReturnType<typeof zodForKind>> = {};
  for (const f of fields) shape[f.key] = zodForKind(f.kind);
  return z.object(shape);
}

// Slug a custom field's label into a stable metadata key — e.g. "Mood Today"
// -> "mood_today". Collisions (two fields with the same slug) are rejected
// by the caller before submit.
export function slugifyFieldKey(label: string): string {
  return label
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

export const CUSTOM_FIELD_KIND_OPTIONS: { label: string; value: CustomField["kind"] }[] = [
  { label: "Text", value: "text" },
  { label: "Number", value: "number" },
  { label: "Long text", value: "textarea" },
];
