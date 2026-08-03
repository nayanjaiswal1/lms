"use client";

import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { HABIT_COLOR_OPTIONS, type HabitColorValue } from "@/lib/constants";
import { cn } from "@/lib/utils";

// Static literal classes (not string-templated) so Tailwind sees every
// class at build time — same pattern as focus-wall's CARD_CLASS.
export const HABIT_SWATCH_CLASS: Record<HabitColorValue, string> = {
  blue: "bg-habit-blue",
  orange: "bg-habit-orange",
  aqua: "bg-habit-aqua",
  yellow: "bg-habit-yellow",
  magenta: "bg-habit-magenta",
  green: "bg-habit-green",
  violet: "bg-habit-violet",
  red: "bg-habit-red",
};

// SVG wedge fill for the daily wheel — same static-literal-class
// requirement as HABIT_SWATCH_CLASS above.
export const HABIT_FILL_CLASS: Record<HabitColorValue, string> = {
  blue: "fill-habit-blue",
  orange: "fill-habit-orange",
  aqua: "fill-habit-aqua",
  yellow: "fill-habit-yellow",
  magenta: "fill-habit-magenta",
  green: "fill-habit-green",
  violet: "fill-habit-violet",
  red: "fill-habit-red",
};

// Checked-state override for <Checkbox> — same static-literal-class
// requirement as HABIT_SWATCH_CLASS above.
export const HABIT_CHECKBOX_CLASS: Record<HabitColorValue, string> = {
  blue: "data-[state=checked]:border-habit-blue data-[state=checked]:bg-habit-blue",
  orange: "data-[state=checked]:border-habit-orange data-[state=checked]:bg-habit-orange",
  aqua: "data-[state=checked]:border-habit-aqua data-[state=checked]:bg-habit-aqua",
  yellow: "data-[state=checked]:border-habit-yellow data-[state=checked]:bg-habit-yellow",
  magenta: "data-[state=checked]:border-habit-magenta data-[state=checked]:bg-habit-magenta",
  green: "data-[state=checked]:border-habit-green data-[state=checked]:bg-habit-green",
  violet: "data-[state=checked]:border-habit-violet data-[state=checked]:bg-habit-violet",
  red: "data-[state=checked]:border-habit-red data-[state=checked]:bg-habit-red",
};

interface HabitColorPickerProps {
  habitName: string;
  color: HabitColorValue;
  onChange: (color: HabitColorValue) => void;
}

export function HabitColorPicker({ habitName, color, onChange }: HabitColorPickerProps) {
  return (
    <Popover>
      <PopoverTrigger
        aria-label={`Change color for ${habitName}`}
        className={cn("touch-target inline-flex shrink-0 items-center justify-center rounded-full")}
      >
        <span aria-hidden className={cn("size-3 rounded-full", HABIT_SWATCH_CLASS[color])} />
      </PopoverTrigger>
      <PopoverContent align="start" className="w-auto p-2">
        <div className="grid grid-cols-4 gap-1">
          {HABIT_COLOR_OPTIONS.map((opt) => (
            <button
              aria-label={opt.label}
              aria-pressed={opt.value === color}
              className="touch-target flex items-center justify-center rounded-md hover:bg-accent"
              key={opt.value}
              type="button"
              onClick={() => onChange(opt.value)}
            >
              <span
                aria-hidden
                className={cn(
                  "size-5 rounded-full ring-offset-2 ring-offset-popover transition-shadow duration-fast",
                  HABIT_SWATCH_CLASS[opt.value],
                  opt.value === color && "ring-2 ring-foreground",
                )}
              />
            </button>
          ))}
        </div>
      </PopoverContent>
    </Popover>
  );
}
