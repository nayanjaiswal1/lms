import Link from "next/link"
import { Maximize2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import ROUTES from "@/lib/routes"

interface KindEmbedNoticeProps {
  sessionId: string
}

/** Shown where a kind lab is embedded inline: the IDE workspace needs the full screen. */
export function KindEmbedNotice({ sessionId }: KindEmbedNoticeProps) {
  return (
    <div className="empty-state flex-1">
      <p className="text-sm text-muted-foreground">
        This lab runs in a full-screen workspace with its own IDE.
      </p>
      <Button asChild>
        <Link href={ROUTES.labSession(sessionId)}>
          <Maximize2 aria-hidden className="mr-2 h-4 w-4" />
          Open lab
        </Link>
      </Button>
    </div>
  )
}
