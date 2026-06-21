import { Clock, LogOut, ShieldAlert, ShieldCheck } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

interface ProctorBannerProps {
  secondsLeft: number;
  violations: number;
  answered: number;
  total: number;
  onExit?: () => void;
}

function formatTime(total: number): string {
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export function ProctorBanner({
  secondsLeft,
  violations,
  answered,
  total,
  onExit,
}: ProctorBannerProps) {
  const low = secondsLeft > 0 && secondsLeft <= 120;
  const expired = secondsLeft === 0;
  const safe = !expired && secondsLeft > 120;

  return (
    <div className="shrink-0 border-b border-border bg-background/95 backdrop-blur-sm">
      <div className="flex h-12 items-center gap-3 px-4 sm:px-6">

        {/* Monitoring status */}
        <div className="flex min-w-0 flex-1 items-center gap-2">
          {violations > 0 ? (
            <ShieldAlert aria-hidden className="h-4 w-4 shrink-0 text-destructive" />
          ) : (
            <ShieldCheck aria-hidden className="h-4 w-4 shrink-0 text-ai" />
          )}
          <span className="hidden text-sm font-medium sm:block">
            {violations > 0 ? "Flags recorded" : "Monitored"}
          </span>
          {violations > 0 && (
            <span
              aria-label={`${violations} violation${violations !== 1 ? "s" : ""}`}
              className="inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-destructive px-1.5 text-xs font-bold tabular-nums text-primary-foreground"
            >
              {violations}
            </span>
          )}
        </div>

        {/* Progress — centre */}
        <div className="flex shrink-0 items-center gap-1.5 text-sm text-muted-foreground">
          <span className="tabular-nums">
            <span className="font-semibold text-foreground">{answered}</span>
            <span className="mx-0.5">/</span>
            <span>{total}</span>
          </span>
          <span className="hidden text-xs sm:inline">answered</span>
        </div>

        {/* Timer + exit */}
        <div className="flex flex-1 items-center justify-end gap-2">
          <span
            aria-live="polite"
            aria-label={`${formatTime(secondsLeft)} remaining`}
            className={cn(
              "inline-flex items-center gap-1.5 rounded-md px-2.5 py-1 font-mono text-sm font-semibold tabular-nums transition-colors duration-normal",
              expired
                ? "bg-destructive text-primary-foreground"
                : low
                  ? "bg-destructive/10 text-destructive"
                  : safe
                    ? "bg-muted text-foreground"
                    : "bg-muted text-foreground",
            )}
          >
            <Clock aria-hidden className="h-3.5 w-3.5" />
            {formatTime(secondsLeft)}
          </span>

          {onExit && (
            <Button
              variant="ghost"
              size="sm"
              onClick={onExit}
              aria-label="Exit test"
              className="h-8 gap-1 px-2 text-muted-foreground hover:text-foreground"
            >
              <LogOut aria-hidden className="h-3.5 w-3.5" />
              <span className="hidden text-xs sm:inline">Exit</span>
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}
