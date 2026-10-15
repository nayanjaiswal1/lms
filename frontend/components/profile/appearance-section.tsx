"use client"

import { Button } from "@/components/ui/button";
import { useSyncExternalStore } from "react"
import { Monitor, Moon, Sun } from "lucide-react"
import { useTheme } from "next-themes"
import { SettingsSection } from "@/components/profile/settings-section"
import { cn } from "@/lib/utils"

const THEME_OPTIONS = [
  { value: "light",  label: "Light",  Icon: Sun },
  { value: "dark",   label: "Dark",   Icon: Moon },
  { value: "system", label: "System", Icon: Monitor },
] as const

const noopSubscribe = () => () => {}

export function AppearanceSection() {
  const { theme, setTheme } = useTheme()
  // theme is undefined on the server and on the client's first render, so
  // deriving `active` from it before mount causes a hydration mismatch that
  // makes React discard this subtree (and its click handlers) on mount.
  const mounted = useSyncExternalStore(noopSubscribe, () => true, () => false)

  return (
    <SettingsSection
      description="Applies instantly on this device. System follows your OS setting."
      id="appearance"
      title="Appearance"
    >
      <fieldset className="grid grid-cols-3 gap-2">
        <legend className="sr-only">Theme</legend>
        {THEME_OPTIONS.map(({ value, label, Icon }) => {
          const active = mounted && theme === value
          return (
            <Button
              aria-pressed={active}
              className={cn(
                "flex min-h-16 flex-col items-center justify-center gap-1.5 rounded-lg border p-4 text-sm font-medium",
                "transition-colors duration-fast ease-smooth focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
                active
                  ? "border-primary bg-primary/5 text-primary"
                  : "border-border text-muted-foreground hover:bg-muted hover:text-foreground"
              )}
              key={value}
              type="button"
              variant="unstyled"
              onClick={() => setTheme(value)}
            >
              <Icon aria-hidden className="h-5 w-5 shrink-0" />
              {label}
            </Button>
          )
        })}
      </fieldset>
    </SettingsSection>
  )
}
