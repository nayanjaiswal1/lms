"use client"

import { Settings } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuCheckboxItem,
} from "@/components/ui/dropdown-menu"
import { useEditorSettings } from "@/hooks/use-editor-settings"
import { EDITOR_FONT_SIZES, EDITOR_TAB_SIZES } from "@/lib/labs/editor-settings"

// Keeps the menu open across toggles (VS Code settings behavior): Radix
// closes the menu on every item select unless the select is prevented.
const keepOpen = (e: Event) => e.preventDefault()

/**
 * VS Code-style editor preferences gear. Settings persist in localStorage and
 * apply live to every Monaco editor and terminal via the shared settings store.
 */
export function EditorSettingsMenu() {
  const { settings, update } = useEditorSettings()

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button aria-label="Editor settings" className="h-7 w-7 p-0" size="sm" variant="ghost">
          <Settings aria-hidden className="h-3.5 w-3.5" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-44">
        <DropdownMenuLabel>Font size</DropdownMenuLabel>
        <DropdownMenuRadioGroup
          value={String(settings.fontSize)}
          onValueChange={(v) => update({ fontSize: Number(v) })}
        >
          {EDITOR_FONT_SIZES.map((size) => (
            <DropdownMenuRadioItem key={size} value={String(size)} onSelect={keepOpen}>
              {size}px
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>
        <DropdownMenuSeparator />
        <DropdownMenuLabel>Tab size</DropdownMenuLabel>
        <DropdownMenuRadioGroup
          value={String(settings.tabSize)}
          onValueChange={(v) => update({ tabSize: Number(v) })}
        >
          {EDITOR_TAB_SIZES.map((size) => (
            <DropdownMenuRadioItem key={size} value={String(size)} onSelect={keepOpen}>
              {size} spaces
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>
        <DropdownMenuSeparator />
        <DropdownMenuCheckboxItem
          checked={settings.wordWrap}
          onCheckedChange={(checked) => update({ wordWrap: checked === true })}
          onSelect={keepOpen}
        >
          Word wrap
        </DropdownMenuCheckboxItem>
        <DropdownMenuCheckboxItem
          checked={settings.minimap}
          onCheckedChange={(checked) => update({ minimap: checked === true })}
          onSelect={keepOpen}
        >
          Minimap
        </DropdownMenuCheckboxItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
