import { Loader2 } from "lucide-react"
import { ScrollArea } from "@/components/ui/scroll-area"
import { cn } from "@/lib/utils"
import type { LabRunResult } from "@/hooks/use-lab-verify"

interface LabCodeConsoleProps {
  result: LabRunResult | null
  isVerifying: boolean
}

export function LabCodeConsole({ result, isVerifying }: LabCodeConsoleProps) {
  return (
    <div className="flex h-full flex-col bg-card">
      <div className="flex items-center gap-2 border-b border-border px-3 py-2 shrink-0">
        <span className="text-xs font-semibold text-foreground">Console</span>
        {result && (
          <span
            className={cn(
              "text-xs font-medium",
              result.passed ? "text-success" : "text-destructive",
            )}
          >
            {result.passed ? "Passed" : "Failed"}
          </span>
        )}
      </div>

      <ScrollArea className="flex-1">
        <div className="p-3">
          {isVerifying ? (
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <Loader2 className="h-3.5 w-3.5 animate-spin" aria-hidden />
              Running your code…
            </div>
          ) : !result ? (
            <p className="text-xs text-muted-foreground">
              Click Check to run your code — output will appear here.
            </p>
          ) : (
            <div className="flex flex-col gap-3">
              {result.stdout && (
                <pre className="whitespace-pre-wrap break-words font-mono text-xs text-foreground">
                  {result.stdout}
                </pre>
              )}
              {result.stderr && (
                <pre className="whitespace-pre-wrap break-words font-mono text-xs text-destructive">
                  {result.stderr}
                </pre>
              )}
              {!result.stdout && !result.stderr && (
                <p className="text-xs text-muted-foreground">No output.</p>
              )}
            </div>
          )}
        </div>
      </ScrollArea>
    </div>
  )
}
