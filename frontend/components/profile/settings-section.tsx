import { cn } from "@/lib/utils"

interface Props {
  id: string
  title: React.ReactNode
  description?: React.ReactNode
  /** Right-aligned header slot (count, status chip, secondary button). */
  action?: React.ReactNode
  className?: string
  children: React.ReactNode
}

/**
 * One section card for every settings surface: heading + description on the
 * left, optional action on the right, content below. A trailing
 * <FormSaveFooter> bleeds to the card edges.
 */
export function SettingsSection({ id, title, description, action, className, children }: Props) {
  const headingId = `${id}-heading`
  return (
    <section aria-labelledby={headingId} className={cn("card-base p-6", className)}>
      <header className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0 space-y-1">
          <h2 className="subsection-title flex flex-wrap items-center gap-2 text-foreground" id={headingId}>
            {title}
          </h2>
          {description && <p className="text-sm text-muted-foreground">{description}</p>}
        </div>
        {action && <div className="shrink-0">{action}</div>}
      </header>
      <div className="mt-6">{children}</div>
    </section>
  )
}
