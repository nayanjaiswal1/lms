"use client";

import { useTheme } from "next-themes";
import { Toaster as Sonner, type ToasterProps } from "sonner";

/**
 * App toast surface. Mounted once in app/layout.tsx.
 * Reads the active theme from next-themes so toasts match light/dark.
 * All success/error feedback goes through `toast()` from sonner — never alert().
 */
export function Toaster(props: ToasterProps) {
  const { theme = "system" } = useTheme();

  return (
    <Sonner
      closeButton
      richColors
      className="toaster group"
      position="bottom-right"
      theme={theme as ToasterProps["theme"]}
      {...props}
    />
  );
}
