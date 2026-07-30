"use client";

import { List, Map as MapIcon } from "lucide-react";
import { parseAsStringLiteral, useQueryState } from "nuqs";
import { Button } from "@/components/ui/button";
import { RoadmapTree } from "@/components/roadmap/roadmap-tree";
import { RoadmapGraph } from "@/components/roadmap/roadmap-graph";
import { cn } from "@/lib/utils";
import type { Roadmap } from "@/lib/server/roadmap";

const VIEWS = ["list", "map"] as const;

export function RoadmapView({ roadmap }: { roadmap: Roadmap }) {
  const [view, setView] = useQueryState("view", parseAsStringLiteral(VIEWS).withDefault("list"));
  const phases = roadmap.phases ?? [];

  return (
    <div className="flex flex-col gap-4">
      <div className="flex w-fit gap-1 rounded-md border border-border p-1">
        <Button
          className={cn("touch-target", view !== "list" && "text-muted-foreground")}
          size="sm"
          variant={view === "list" ? "secondary" : "ghost"}
          onClick={() => setView("list")}
        >
          <List aria-hidden className="h-4 w-4" />
          List
        </Button>
        <Button
          className={cn("touch-target", view !== "map" && "text-muted-foreground")}
          size="sm"
          variant={view === "map" ? "secondary" : "ghost"}
          onClick={() => setView("map")}
        >
          <MapIcon aria-hidden className="h-4 w-4" />
          Map
        </Button>
      </div>

      {view === "map" ? <RoadmapGraph phases={phases} roadmapId={roadmap.id} /> : <RoadmapTree roadmap={roadmap} />}
    </div>
  );
}
