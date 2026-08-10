import type { LucideIcon } from "lucide-react";
import { customHabitIcon } from "@/lib/habits/icons";
import { cn } from "@/lib/utils";

interface HabitIconProps {
  icon: string;
  fallback: LucideIcon;
  className?: string;
}

// Renders a habit's icon: a curated lucide component, a typed emoji (plain
// text — no icon font/library covers arbitrary emoji), or the caller's
// fallback (type or cadence icon) when icon is "" (no override).
export function HabitIcon({ icon, fallback: Fallback, className }: HabitIconProps) {
  const resolved = customHabitIcon(icon);
  if (resolved?.kind === "emoji") {
    return (
      <span aria-hidden className={cn("inline-block text-center leading-none", className)}>
        {resolved.value}
      </span>
    );
  }
  const Icon = resolved?.Icon ?? Fallback;
  return <Icon aria-hidden className={className} />;
}
