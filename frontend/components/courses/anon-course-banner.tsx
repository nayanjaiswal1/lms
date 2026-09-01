import Link from "next/link";
import { Info } from "lucide-react";
import ROUTES from "@/lib/routes";

interface AnonCourseBannerProps {
  nextPath: string;
}

// Sits above the lesson content on every anonymously-viewed public course
// page (docs/anonymous.md) — the one place that tells the visitor their
// completions/notes/reflections are browser-local, and gives them a way out
// (sign in) that carries them back to the exact lesson they were on.
export function AnonCourseBanner({ nextPath }: AnonCourseBannerProps) {
  return (
    <div className="mb-6 flex flex-wrap items-center gap-2 rounded-lg border border-primary/30 bg-accent px-4 py-2.5 text-sm text-foreground">
      <Info aria-hidden className="h-4 w-4 shrink-0 text-primary" />
      <span className="min-w-0 flex-1">
        Browsing without an account — progress is saved in this browser only.
      </span>
      <Link
        className="shrink-0 font-medium text-primary underline underline-offset-2"
        href={`${ROUTES.LOGIN}?next=${encodeURIComponent(nextPath)}`}
      >
        Sign in to save it
      </Link>
    </div>
  );
}
