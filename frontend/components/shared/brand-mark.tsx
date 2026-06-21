import { Flame } from "lucide-react";
import { cn } from "@/lib/utils";

interface BrandMarkProps {
  className?: string;
  showName?: boolean;
}

// The MindForge wordmark — an amber flame tile beside the name. Reused across
// auth pages (and anywhere the brand needs to appear) so the lockup is defined once.
export function BrandMark({ className, showName = true }: BrandMarkProps) {
  return (
    <span className={cn("inline-flex items-center gap-2.5", className)}>
      <span className="flex-center h-9 w-9 shrink-0 rounded-md bg-primary text-primary-foreground">
        <Flame aria-hidden className="h-5 w-5" />
      </span>
      {showName && (
        <span className="text-lg font-bold tracking-tight text-foreground">
          MindForge
        </span>
      )}
    </span>
  );
}
