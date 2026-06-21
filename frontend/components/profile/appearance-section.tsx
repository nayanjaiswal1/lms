"use client"

import { Monitor, Moon, Sun } from "lucide-react"
import { useTheme } from "next-themes"
import { cn } from "@/lib/utils"

const THEME_OPTIONS = [
  { value: "light",  label: "Light",  Icon: Sun },
  { value: "dark",   label: "Dark",   Icon: Moon },
  { value: "system", label: "System", Icon: Monitor },
] as const

export function AppearanceSection() {
  const { theme, setTheme } = useTheme()

  return (
    <section aria-label="Appearance" className="card-base p-6 space-y-4">
      <h2 className="section-title text-lg">Appearance</h2>

      <div className="space-y-1.5">
        <p className="text-sm font-medium text-foreground">Theme</p>
        <div className="flex gap-2">
          {THEME_OPTIONS.map(({ value, label, Icon }) => {
            const active = theme === value
            return (
              <button
                key={value}
                type="button"
                aria-pressed={active}
                onClick={() => setTheme(value)}
                className={cn(
                  "flex flex-1 flex-col items-center justify-center gap-1.5 h-16 rounded-lg border text-xs font-medium transition-colors",
                  active
                    ? "border-primary text-primary"
                    : "border-border text-muted-foreground hover:text-foreground hover:border-border"
                )}
              >
                <Icon className="h-4 w-4 shrink-0" aria-hidden />
                {label}
              </button>
            )
          })}
        </div>
        <p className="text-xs text-muted-foreground">
          System follows your OS colour preference.
        </p>
      </div>
    </section>
  )
}
