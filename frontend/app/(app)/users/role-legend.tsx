"use client";

import { Info } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { ROLE_ICONS } from "@/app/(app)/users/role-badges";

// Toolbar control that reveals the role-icon → role-name mapping on demand,
// instead of repeating it as always-visible text next to the search bar.
export function RoleLegend() {
  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button aria-label="Role icon legend" className="gap-1.5" size="sm" variant="outline">
          <Info aria-hidden className="h-3.5 w-3.5" />
          Role icons
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-56">
        <p className="text-xs font-semibold text-muted-foreground mb-2">Role icon legend</p>
        <div className="flex flex-col gap-1.5">
          {Object.entries(ROLE_ICONS).map(([name, Icon]) => (
            <div className="flex items-center gap-2 text-sm" key={name}>
              <Icon aria-hidden className="h-3.5 w-3.5 text-muted-foreground" />
              {name.replace("_", " ")}
            </div>
          ))}
        </div>
      </PopoverContent>
    </Popover>
  );
}
