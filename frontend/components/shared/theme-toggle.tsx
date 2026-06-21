"use client";

import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";

/**
 * Light/dark toggle. Both icons are rendered and swapped purely via CSS
 * (.theme-icon-sun / .theme-icon-moon keyed off the .dark class), so there is
 * no hydration mismatch and no mounted/useEffect guard. The click reads the
 * resolved theme at event time — after hydration — which is always correct.
 */
export function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme();

  return (
    <Button
      aria-label="Toggle light or dark theme"
      size="icon"
      variant="ghost"
      onClick={() => setTheme(resolvedTheme === "dark" ? "light" : "dark")}
    >
      <Sun aria-hidden className="theme-icon-sun h-4 w-4" />
      <Moon aria-hidden className="theme-icon-moon h-4 w-4" />
    </Button>
  );
}
