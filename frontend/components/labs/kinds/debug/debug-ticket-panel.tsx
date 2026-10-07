import { Ticket } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { LabMarkdown } from "@/components/labs/kinds/debug/lab-markdown"
import { parseTicketMeta } from "@/lib/labs/kinds/debug-ticket"

interface DebugTicketPanelProps {
  title: string
  brief: string
}

/** The incident ticket the student starts from — reporter, severity, then the authored brief. */
export function DebugTicketPanel({ title, brief }: DebugTicketPanelProps) {
  const { severity, reporter, body } = parseTicketMeta(brief)
  // A brief that opens with its own "# Title" already names the incident.
  const hasOwnTitle = /^#\s/.test(body)

  return (
    <section aria-label="Incident ticket" className="flex flex-col gap-3">
      <header className="flex flex-col gap-2 border-b border-border pb-3">
        <div className="flex flex-wrap items-center gap-2">
          <Badge className="gap-1" variant="outline">
            <Ticket aria-hidden className="h-3 w-3" />
            Incident
          </Badge>
          {severity && <Badge variant="destructive">{severity}</Badge>}
          {reporter && (
            <span className="text-xs leading-5 text-muted-foreground">
              Reported by <span className="font-medium text-foreground">{reporter}</span>
            </span>
          )}
        </div>
        {!hasOwnTitle && <h2 className="text-base font-semibold leading-snug">{title}</h2>}
      </header>
      <LabMarkdown>{body}</LabMarkdown>
    </section>
  )
}
