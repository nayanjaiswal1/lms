"use client";

import { Pause, Play, SkipBack, SkipForward, StepBack, StepForward } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Slider } from "@/components/ui/slider";

const SPEED_OPTIONS = [
  { label: "0.5x", ms: 1200 },
  { label: "1x", ms: 600 },
  { label: "2x", ms: 300 },
  { label: "4x", ms: 150 },
];

interface PlaybackControlsProps {
  currentIndex: number;
  total: number;
  playing: boolean;
  speedMs: number;
  funcName: string;
  onFirst: () => void;
  onPrev: () => void;
  onNext: () => void;
  onLast: () => void;
  onSeek: (index: number) => void;
  onTogglePlay: () => void;
  onSpeedChange: (ms: number) => void;
}

export function PlaybackControls({
  currentIndex,
  total,
  playing,
  speedMs,
  funcName,
  onFirst,
  onPrev,
  onNext,
  onLast,
  onSeek,
  onTogglePlay,
  onSpeedChange,
}: PlaybackControlsProps) {
  const disabled = total === 0;
  return (
    <div className="flex flex-col gap-3 rounded-lg border border-border bg-card p-3 sm:flex-row sm:items-center sm:gap-4">
      <div className="flex items-center justify-center gap-1">
        <Button aria-label="First step" disabled={disabled} size="icon" variant="outline" onClick={onFirst}>
          <SkipBack aria-hidden className="h-4 w-4" />
        </Button>
        <Button aria-label="Previous step" disabled={disabled} size="icon" variant="outline" onClick={onPrev}>
          <StepBack aria-hidden className="h-4 w-4" />
        </Button>
        <Button aria-label={playing ? "Pause" : "Play"} disabled={disabled} size="icon" variant="default" onClick={onTogglePlay}>
          {playing ? <Pause aria-hidden className="h-4 w-4" /> : <Play aria-hidden className="h-4 w-4" />}
        </Button>
        <Button aria-label="Next step" disabled={disabled} size="icon" variant="outline" onClick={onNext}>
          <StepForward aria-hidden className="h-4 w-4" />
        </Button>
        <Button aria-label="Last step" disabled={disabled} size="icon" variant="outline" onClick={onLast}>
          <SkipForward aria-hidden className="h-4 w-4" />
        </Button>
      </div>

      <div className="flex flex-1 items-center gap-3">
        <Slider
          aria-label="Step scrubber"
          disabled={disabled}
          max={Math.max(0, total - 1)}
          min={0}
          step={1}
          value={[currentIndex]}
          onValueChange={([v]) => onSeek(v)}
        />
        <span className="w-28 shrink-0 text-right font-mono text-xs text-muted-foreground">
          {disabled ? "No steps" : `Step ${currentIndex + 1} / ${total}`}
        </span>
      </div>

      <div className="flex items-center gap-2">
        {!disabled && <span className="font-mono text-xs text-muted-foreground">in {funcName}()</span>}
        <Select value={String(speedMs)} onValueChange={(v) => onSpeedChange(Number(v))}>
          <SelectTrigger className="w-20">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {SPEED_OPTIONS.map((o) => (
              <SelectItem key={o.ms} value={String(o.ms)}>
                {o.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
    </div>
  );
}
