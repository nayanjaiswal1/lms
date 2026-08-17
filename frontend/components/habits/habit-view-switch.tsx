"use client";

import { LayoutGrid, PieChart } from "lucide-react";
import { parseAsStringLiteral, useQueryState } from "nuqs";
import { VIEWS } from "@/components/habits/habit-board";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

// Same "view" query key/parser as HabitBoard's own useQueryState — nuqs
// keeps both in sync through the URL rather than needing prop drilling, so
// this can live beside the "What Now?" button at the page level instead of
// inside the board itself.
export function HabitViewSwitch() {
  const [view, setView] = useQueryState("view", parseAsStringLiteral(VIEWS).withDefault("wheel"));

  return (
    <div className="relative flex w-fit gap-1 rounded-full border border-border bg-background p-1 shadow-card">
      {/* Sliding highlight — one shared pill that translates behind whichever
          button is active, instead of each button flipping its own bg
          instantly. Buttons are size="icon" (h-10 w-10) but .touch-target's
          min-h-11/min-w-11 wins, so the actual rendered box is 44px —
          translate-x-12 = 44px button + 4px gap-1, landing behind button 2. */}
      <div
        aria-hidden
        className={cn(
          "absolute left-1 top-1 h-11 w-11 rounded-full bg-secondary transition-transform duration-normal ease-smooth",
          view === "grid" && "translate-x-12",
        )}
      />
      <Button
        aria-label="Wheel view"
        className={cn("touch-target relative z-10 rounded-full", view !== "wheel" && "text-muted-foreground")}
        size="icon"
        title="Wheel view"
        variant="ghost"
        onClick={() => setView("wheel")}
      >
        <PieChart aria-hidden className="h-4 w-4" />
      </Button>
      <Button
        aria-label="Grid view"
        className={cn("touch-target relative z-10 rounded-full", view !== "grid" && "text-muted-foreground")}
        size="icon"
        title="Grid view"
        variant="ghost"
        onClick={() => setView("grid")}
      >
        <LayoutGrid aria-hidden className="h-4 w-4" />
      </Button>
    </div>
  );
}
