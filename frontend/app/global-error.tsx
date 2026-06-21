"use client";

// global-error catches errors thrown in the ROOT layout itself — the one case
// app/error.tsx cannot handle, because it lives inside that layout. It must
// render its own <html>/<body> since it replaces the entire shell.

interface GlobalErrorProps {
  error: Error & { digest?: string };
  reset: () => void;
}

export default function GlobalError({ error, reset }: GlobalErrorProps) {
  return (
    <html lang="en">
      <body className="bg-background text-foreground font-sans antialiased">
        <main className="flex-center min-h-dvh flex-col gap-4 p-6 text-center">
          <div>
            <h1 className="text-xl font-semibold">Something went wrong</h1>
            <p className="mt-1 text-sm text-muted-foreground">
              {error.digest ? `Error ID: ${error.digest}` : "An unexpected error occurred."}
            </p>
          </div>
          <button
            className="inline-flex h-10 items-center rounded-md border border-border bg-background px-5 text-sm font-medium hover:bg-accent"
            type="button"
            onClick={reset}
          >
            Try again
          </button>
        </main>
      </body>
    </html>
  );
}
