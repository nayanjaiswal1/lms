"use client";

import * as React from "react";
import { Button } from "@/components/ui/button";
import { Clock } from "lucide-react";

interface TimeBlockPresetsProps {
  onSelect: (minutes: number, label: string) => void;
}

const PRESETS = [
  { label: "15 min", minutes: 15 },
  { label: "30 min", minutes: 30 },
  { label: "1 hour", minutes: 60 },
  { label: "1.5 hours", minutes: 90 },
  { label: "2 hours", minutes: 120 },
  { label: "3 hours", minutes: 180 },
  { label: "4 hours", minutes: 240 },
];

export function TimeBlockPresets({ onSelect }: TimeBlockPresetsProps) {
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
        <Clock className="h-4 w-4" />
        Duration presets
      </div>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
        {PRESETS.map((preset) => (
          <Button
            key={preset.minutes}
            size="sm"
            type="button"
            variant="outline"
            className="text-xs"
            onClick={() => onSelect(preset.minutes, preset.label)}
          >
            {preset.label}
          </Button>
        ))}
      </div>
    </div>
  );
}
