import * as React from "react";
import { cn } from "@/lib/utils";

/** Loading placeholder. Uses the .skeleton utility from globals.css. */
function Skeleton({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("skeleton", className)} {...props} />;
}

export { Skeleton };
