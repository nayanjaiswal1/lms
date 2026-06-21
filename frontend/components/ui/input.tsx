import * as React from "react";
import { cn } from "@/lib/utils";

// The focus ring is intentionally NOT declared here — globals.css :focus-visible
// owns the amber brand ring for every interactive element (same as button.tsx).
// h-11 keeps the field at a 44px touch target (WCAG 2.5.5).
function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        "flex h-11 w-full rounded-md border border-input bg-background px-3 py-2.5",
        "text-sm text-foreground shadow-sm transition-colors outline-none",
        "placeholder:text-muted-foreground",
        "disabled:cursor-not-allowed disabled:opacity-50",
        "aria-invalid:border-destructive",
        className,
      )}
      {...props}
    />
  );
}

export { Input };
