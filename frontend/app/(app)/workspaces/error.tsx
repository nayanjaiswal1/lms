"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";

interface ErrorProps {
  error: Error & { digest?: string };
  reset: () => void;
}

export default function WorkspacesError({ error, reset }: ErrorProps) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="flex-center min-h-[60vh] flex-col gap-4 text-center">
      <div>
        <h2 className="text-xl font-semibold">Couldn&apos;t load this workspace</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          {error.digest ? `Error ID: ${error.digest}` : "An unexpected error occurred."}
        </p>
      </div>
      <Button size="sm" variant="outline" onClick={reset}>
        Try again
      </Button>
    </div>
  );
}
