import { Lock } from "lucide-react";

/** Shown instead of a section's controls when the caller's project role is
 * below what that section needs — never a 404/notFound(), which is reserved
 * for cross-project id probing and unknown share tokens (see 04-frontend.md §7). */
export function ForbiddenSection() {
  return (
    <div className="empty-state">
      <Lock aria-hidden className="empty-state-icon" />
      <p className="font-medium text-muted-foreground">You don&apos;t have access to this section.</p>
    </div>
  );
}
