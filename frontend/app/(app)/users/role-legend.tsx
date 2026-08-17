"use client";

import { Info } from "lucide-react";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { ROLE_ICONS } from "@/app/(app)/users/role-badges";

// Sits right next to the "Roles" column header, since that's where the
// icon-only stack that needs decoding actually lives. Hover, not click —
// it's a passive hint, not an action, so it shouldn't look or behave like
// a button. The trigger is still a real <button> (unstyled) so it stays
// keyboard-focusable and announced to screen readers.
export function RoleLegend() {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button aria-label="Role icon legend" className="text-muted-foreground hover:text-foreground" type="button">
          <Info aria-hidden className="h-3 w-3" />
        </button>
      </TooltipTrigger>
      <TooltipContent align="start" className="flex flex-col gap-1.5">
        {Object.entries(ROLE_ICONS).map(([name, Icon]) => (
          <div className="flex items-center gap-2" key={name}>
            <Icon aria-hidden className="h-3.5 w-3.5" />
            {name.replace("_", " ")}
          </div>
        ))}
      </TooltipContent>
    </Tooltip>
  );
}
