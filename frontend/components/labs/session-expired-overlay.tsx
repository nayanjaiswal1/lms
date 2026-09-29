import { LogIn } from "lucide-react"
import { Button } from "@/components/ui/button"

interface SessionExpiredOverlayProps {
  onLogin: () => void
}

export function SessionExpiredOverlay({ onLogin }: SessionExpiredOverlayProps) {
  return (
    <div
      aria-live="assertive"
      className="absolute inset-0 z-modal flex flex-col items-center justify-center gap-4 bg-background/95 backdrop-blur-sm px-6"
      role="alert"
    >
      <div className="flex flex-col items-center gap-3 text-center max-w-xs">
        <div className="rounded-full bg-muted p-4">
          <LogIn aria-hidden className="h-6 w-6 text-muted-foreground" />
        </div>
        <div className="flex flex-col gap-1.5">
          <p className="font-semibold text-foreground">Session expired</p>
          <p className="text-sm text-muted-foreground">
            Your login session has expired. Please log in again to continue — your progress is
            saved.
          </p>
        </div>
        <Button className="w-full" onClick={onLogin}>
          Log in again
        </Button>
      </div>
    </div>
  )
}
