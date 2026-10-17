"use client";

import { ChevronLeft, ChevronRight, Download, ListChecks, Plus, SlidersHorizontal } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { SegmentedControl } from "@/app/(app)/calendar/segmented-control";
import { CALENDAR_LAYER_OPTIONS, CALENDAR_VIEW_OPTIONS } from "@/lib/calendar/types";
import type { CalendarLayer, CalendarView } from "@/lib/calendar/types";
import { cn } from "@/lib/utils";

interface CalendarToolbarProps {
  view: CalendarView;
  rangeLabel: string;
  activeLayers: CalendarLayer[];
  tasksOnly: boolean;
  onViewChange: (view: CalendarView) => void;
  onNavigate: (direction: 1 | -1) => void;
  onToday: () => void;
  onToggleLayer: (layer: CalendarLayer) => void;
  onToggleTasksOnly: () => void;
  onNewEvent: () => void;
  onExportIcs: () => void;
}

export function CalendarToolbar({
  view,
  rangeLabel,
  activeLayers,
  tasksOnly,
  onViewChange,
  onNavigate,
  onToday,
  onToggleLayer,
  onToggleTasksOnly,
  onNewEvent,
  onExportIcs,
}: CalendarToolbarProps) {
  const activeSwatches = CALENDAR_LAYER_OPTIONS.filter((l) => activeLayers.includes(l.value));

  return (
    <TooltipProvider delayDuration={200}>
      <div className="flex flex-col gap-3">
        {/* Row 1 — where you are + how to move. */}
        <div className="flex items-center gap-2">
          <h2 aria-live="polite" className="subsection-title min-w-0 flex-1 truncate sm:text-2xl">
            {rangeLabel}
          </h2>
          <Button className="touch-target-dense" size="sm" variant="outline" onClick={onToday}>
            Today
          </Button>
          <div className="flex items-center rounded-md border border-border bg-background">
            <Button aria-label="Previous" className="touch-target-dense rounded-r-none lg:h-9 lg:w-9" size="icon" variant="ghost" onClick={() => onNavigate(-1)}>
              <ChevronLeft aria-hidden />
            </Button>
            <span aria-hidden className="h-5 w-px bg-border" />
            <Button aria-label="Next" className="touch-target-dense rounded-l-none lg:h-9 lg:w-9" size="icon" variant="ghost" onClick={() => onNavigate(1)}>
              <ChevronRight aria-hidden />
            </Button>
          </div>
        </div>

        {/* Row 2 — what you see. View switcher spans the full width on mobile. */}
        <div className="flex flex-col gap-2 md:flex-row md:items-center">
          <SegmentedControl
            className="w-full md:w-auto"
            label="Calendar view"
            options={CALENDAR_VIEW_OPTIONS}
            value={view}
            onChange={onViewChange}
          />

          <div className="flex min-w-0 items-center gap-2 md:ml-auto">
            <DropdownMenu>
              <Tooltip>
                <TooltipTrigger asChild>
                  <DropdownMenuTrigger asChild>
                    <Button aria-label="Filter calendars" className="touch-target-dense shrink-0 gap-2" size="sm" variant="outline">
                      <SlidersHorizontal aria-hidden className="sm:hidden" />
                      <span aria-hidden className="hidden -space-x-1 sm:flex">
                        {activeSwatches.slice(0, 3).map((layer) => (
                          <span className={cn("h-2.5 w-2.5 rounded-full ring-2 ring-background", layer.swatchClassName)} key={layer.value} />
                        ))}
                      </span>
                      <span className="hidden sm:inline">Calendars</span>
                    </Button>
                  </DropdownMenuTrigger>
                </TooltipTrigger>
                <TooltipContent>
                  {activeSwatches.length} of {CALENDAR_LAYER_OPTIONS.length} calendars shown
                </TooltipContent>
              </Tooltip>
              <DropdownMenuContent align="end">
                {CALENDAR_LAYER_OPTIONS.map((layer) => (
                  <DropdownMenuCheckboxItem
                    checked={activeLayers.includes(layer.value)}
                    className="min-h-11 lg:min-h-0"
                    key={layer.value}
                    onCheckedChange={() => onToggleLayer(layer.value)}
                    onSelect={(e) => e.preventDefault()}
                  >
                    <span aria-hidden className={cn("mr-2 h-2.5 w-2.5 rounded-full", layer.swatchClassName)} />
                    {layer.label}
                  </DropdownMenuCheckboxItem>
                ))}
              </DropdownMenuContent>
            </DropdownMenu>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  aria-label="Show only my tasks, sorted by priority"
                  aria-pressed={tasksOnly}
                  className="touch-target-dense shrink-0 gap-2"
                  size="sm"
                  variant={tasksOnly ? "default" : "outline"}
                  onClick={onToggleTasksOnly}
                >
                  <ListChecks aria-hidden />
                  <span className="hidden lg:inline">My tasks</span>
                </Button>
              </TooltipTrigger>
              <TooltipContent>Tasks only, sorted by priority</TooltipContent>
            </Tooltip>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button aria-label="Export .ics feed" className="touch-target-dense shrink-0 lg:h-9 lg:w-9" size="icon" variant="outline" onClick={onExportIcs}>
                  <Download aria-hidden />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Export .ics feed</TooltipContent>
            </Tooltip>

            <Button aria-label="New event" className="touch-target-dense shrink-0" size="sm" onClick={onNewEvent}>
              <Plus aria-hidden />
              <span className="hidden sm:inline">New event</span>
            </Button>
          </div>
        </div>
      </div>
    </TooltipProvider>
  );
}
