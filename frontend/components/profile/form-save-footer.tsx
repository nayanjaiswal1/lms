"use client"

import { useFormStatus } from "react-dom"
import { Button } from "@/components/ui/button"

interface Props {
  label: string
  hint?: string
}

/**
 * Save bar for a form that is the last child of a <SettingsSection>. Bleeds to
 * the card edges and sticks to the viewport bottom on lg+ so long forms keep
 * their save button in reach (mobile has the bottom-nav there instead).
 */
export function FormSaveFooter({ label, hint }: Props) {
  const { pending } = useFormStatus()
  return (
    <div className="-mx-6 -mb-6 mt-2 flex flex-col-reverse gap-3 rounded-b-lg border-t border-border bg-muted px-6 py-4 sm:flex-row sm:items-center sm:justify-between lg:sticky lg:bottom-0 lg:z-raised">
      <p className="text-xs text-muted-foreground">{hint}</p>
      <Button aria-busy={pending} className="w-full sm:w-auto" disabled={pending} size="lg" type="submit">
        {pending ? "Saving…" : label}
      </Button>
    </div>
  )
}
