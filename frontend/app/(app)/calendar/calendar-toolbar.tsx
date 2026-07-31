"use client";

import { ChevronLeft, ChevronRight, Download, ListChecks, Plus, Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { CALENDAR_LAYER_OPTIONS, CALENDAR_VIEW_OPTIONS } from "@/lib/calendar/types";
import type { CalendarLayer, CalendarView } from "@/lib/calendar/types";

interface CalendarToolbarProps {
  view: CalendarView;
  rangeLabel: string;
  search: string;
  activeLayers: CalendarLayer[];
  tasksOnly: boolean;
  onViewChange: (view: CalendarView) => void;
  onNavigate: (direction: 1 | -1) => void;
  onToday: () => void;
  onSearchChange: (value: string) => void;
  onToggleLayer: (layer: CalendarLayer) => void;
  onToggleTasksOnly: () => void;
  onNewEvent: () => void;
  onExportIcs: () => void;
}

export function CalendarToolbar({
  view,
  rangeLabel,
  search,
  activeLayers,
  tasksOnly,
  onViewChange,
  onNavigate,
  onToday,
  onSearchChange,
  onToggleLayer,
  onToggleTasksOnly,
  onNewEvent,
  onExportIcs,
}: CalendarToolbarProps) {
  const activeSwatches = CALENDAR_LAYER_OPTIONS.filter((l) => activeLayers.includes(l.value)).slice(0, 3);

  return (
    <TooltipProvider delayDuration={200}>
      <div className="flex flex-wrap items-center gap-2 sm:gap-3">
        <div className="flex items-center gap-2">
          <Button aria-label="Previous" size="icon" variant="outline" onClick={() => onNavigate(-1)}>
            <ChevronLeft aria-hidden className="h-4 w-4" />
          </Button>
          <Button aria-label="Next" size="icon" variant="outline" onClick={() => onNavigate(1)}>
            <ChevronRight aria-hidden className="h-4 w-4" />
          </Button>
          <Button size="sm" variant="outline" onClick={onToday}>
            Today
          </Button>
        </div>

        <h2 className="subsection-title whitespace-nowrap">{rangeLabel}</h2>

        <div aria-hidden className="hidden h-6 w-px bg-border sm:block" />

        <div className="relative w-full sm:w-40 md:w-48">
          <Search aria-hidden className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            aria-label="Search events by title or notes"
            className="pl-9"
            placeholder="Search…"
            type="search"
            value={search}
            onChange={(e) => onSearchChange(e.target.value)}
          />
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button className="gap-2" size="sm" variant="outline">
              {activeSwatches.length > 0 && (
                <span aria-hidden className="flex -space-x-1">
                  {activeSwatches.map((layer) => (
                    <span className={`h-2.5 w-2.5 rounded-full ring-2 ring-card ${layer.swatchClassName}`} key={layer.value} />
                  ))}
                </span>
              )}
              Filters
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="start">
            {CALENDAR_LAYER_OPTIONS.map((layer) => (
              <DropdownMenuCheckboxItem
                checked={activeLayers.includes(layer.value)}
                key={layer.value}
                onCheckedChange={() => onToggleLayer(layer.value)}
                onSelect={(e) => e.preventDefault()}
              >
                <span aria-hidden className={`mr-2 h-2.5 w-2.5 rounded-full ${layer.swatchClassName}`} />
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
              className="touch-target gap-2"
              size="sm"
              variant={tasksOnly ? "default" : "outline"}
              onClick={onToggleTasksOnly}
            >
              <ListChecks aria-hidden className="h-4 w-4" />
              My Tasks
            </Button>
          </TooltipTrigger>
          <TooltipContent>Filter to tasks, sorted by priority</TooltipContent>
        </Tooltip>

        <Tooltip>
          <TooltipTrigger asChild>
            <Button aria-label="Export .ics" size="icon" variant="outline" onClick={onExportIcs}>
              <Download aria-hidden className="h-4 w-4" />
            </Button>
          </TooltipTrigger>
          <TooltipContent>Export .ics</TooltipContent>
        </Tooltip>

        <div className="ml-auto flex items-center gap-2">
          <div className="flex rounded-md border border-border p-0.5">
            {CALENDAR_VIEW_OPTIONS.map((opt) => (
              <button
                className={`rounded px-3 py-1.5 text-sm font-medium transition-colors duration-fast ease-smooth touch-target ${
                  view === opt.value
                    ? "bg-primary text-primary-foreground"
                    : "text-muted-foreground hover:bg-muted hover:text-foreground"
                }`}
                key={opt.value}
                type="button"
                onClick={() => onViewChange(opt.value)}
              >
                {opt.label}
              </button>
            ))}
          </div>
          <Button size="sm" onClick={onNewEvent}>
            <Plus aria-hidden className="mr-1.5 h-4 w-4" />
            New event
          </Button>
        </div>
      </div>
    </TooltipProvider>
  );
}
