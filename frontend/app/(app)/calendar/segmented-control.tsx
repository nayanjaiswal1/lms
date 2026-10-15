"use client";

import type { LucideIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface SegmentedControlProps<T extends string> {
  label: string;
  value: T;
  options: readonly { label: string; value: T; icon?: LucideIcon }[];
  onChange: (value: T) => void;
  className?: string;
}

/** Equal-width pill segments on a muted track — fills its row on mobile so
 * every segment stays a full 44px target. */
export function SegmentedControl<T extends string>({ label, value, options, onChange, className }: SegmentedControlProps<T>) {
  return (
    <fieldset className={cn("flex min-w-0 rounded-lg bg-muted p-1", className)}>
      <legend className="sr-only">{label}</legend>
      {options.map((opt) => {
        const active = opt.value === value;
        const Icon = opt.icon;
        return (
          <Button
            aria-pressed={active}
            className={cn(
              "touch-target-dense flex-1 gap-1.5 rounded-md px-3 text-sm font-medium transition-colors duration-fast ease-smooth lg:h-8",
              active ? "bg-background text-foreground shadow-raised" : "text-muted-foreground hover:text-foreground",
            )}
            key={opt.value}
            type="button"
            variant="unstyled"
            onClick={() => onChange(opt.value)}
          >
            {Icon && <Icon aria-hidden className="h-4 w-4" />}
            {opt.label}
          </Button>
        );
      })}
    </fieldset>
  );
}
