import * as React from "react";
import { cn } from "@/lib/utils";

// Textarea matches the input primitive's padding/border tokens (px-3 py-2.5).
function Textarea({ className, ...props }: React.ComponentProps<"textarea">) {
  return (
    <textarea
      className={cn(
        "flex min-h-20 w-full rounded-md border border-border bg-background px-3 py-2.5 text-sm outline-none transition-colors placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50",
        className,
      )}
      {...props}
    />
  );
}

export { Textarea };
