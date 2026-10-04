"use client"

import { Button } from "@/components/ui/button"

interface ErrorProps {
  error: Error & { digest?: string }
  reset: () => void
}

export default function LabSessionError({ error, reset }: ErrorProps) {
  return (
    <div className="flex-center min-h-[60vh] flex-col gap-4 text-center">
      <div>
        <h2 className="text-xl font-semibold">Couldn&apos;t load this lab session</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          {error.digest ? `Error ID: ${error.digest}` : "An unexpected error occurred."}
        </p>
      </div>
      <Button size="sm" variant="outline" onClick={reset}>
        Try again
      </Button>
    </div>
  )
}
