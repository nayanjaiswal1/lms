"use client";

import { useRef, useState } from "react";
import { Command as CommandPrimitive } from "cmdk";
import { Check, Search, X } from "lucide-react";
import { RemoveScroll } from "react-remove-scroll";
import { Badge } from "@/components/ui/badge";
import { Popover, PopoverAnchor, PopoverContent } from "@/components/ui/popover";
import { Command, CommandEmpty, CommandGroup, CommandItem, CommandList } from "@/components/ui/command";
import type { ChecklistOption } from "@/components/shared/checklist-grid";
import { cn } from "@/lib/utils";

interface Props {
  options: ChecklistOption[];
  selected: Set<string>;
  onToggle: (id: string) => void;
  placeholder: string;
  disabled?: boolean;
}

// cmdk-backed combobox (the shadcn-ecosystem standard for a searchable
// multi-select) instead of a hand-rolled filter/list: `Command` supplies
// keyboard nav and filtering. The search input itself is the Popover's
// anchor (always visible, styled as a normal field) rather than a button
// that reveals a second search box on click — Command's context still
// covers both, so search/filtering stays wired even though the input and
// the results list sit in different parts of the DOM (list is portaled).
// Selected items render as removable chips in their own row below.
// `selected` is the caller's actual saved state (assigned roles, granted
// permissions) — toggling calls back immediately, no separate submit step.
export function MultiSelectDropdown({
  options,
  selected,
  onToggle,
  placeholder,
  disabled,
}: Props) {
  const [open, setOpen] = useState(false);
  const anchorRef = useRef<HTMLDivElement>(null);

  const selectedOptions = options.filter((o) => selected.has(o.id));
  const isGrouped = options.some((o) => o.group !== undefined);
  const grouped = options.reduce<Record<string, ChecklistOption[]>>((acc, opt) => {
    const key = isGrouped ? (opt.group ?? "") : "";
    (acc[key] ??= []).push(opt);
    return acc;
  }, {});
  const groupNames = Object.keys(grouped).sort();

  return (
    <div className="space-y-2">
      <Command className="overflow-visible bg-transparent p-0">
        <Popover open={open} onOpenChange={setOpen}>
          <PopoverAnchor asChild>
            <div className="relative" ref={anchorRef}>
              <Search
                aria-hidden
                className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
              />
              <CommandPrimitive.Input
                className={cn(
                  "flex h-11 w-full rounded-md border border-input bg-background py-2.5 pl-9 pr-3",
                  "text-sm text-foreground shadow-sm outline-none",
                  "placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50",
                )}
                disabled={disabled}
                placeholder={placeholder}
                onFocus={() => setOpen(true)}
              />
            </div>
          </PopoverAnchor>
          <PopoverContent
            align="start"
            className="w-(--radix-popper-anchor-width) rounded-md border-input bg-background p-0 shadow-sm"
            sideOffset={4}
            onInteractOutside={(e) => {
              // The trigger *is* the search input (no separate button), so the
              // click that focuses it and opens this content is itself seen as
              // an "outside" pointerdown once the content mounts — without this
              // guard the popover opens and immediately closes on that same click.
              if (anchorRef.current?.contains(e.target as Node)) e.preventDefault();
            }}
            onOpenAutoFocus={(e) => e.preventDefault()}
          >
            {/* Radix Dialog locks page scroll via react-remove-scroll, whose shard
                list only covers the dialog's own content ref — this list is
                portaled to document.body as a sibling, so it's invisible to that
                shard check and every wheel/touch event on it gets preventDefault'd
                as "outside" traffic (see docs/frontend-gotchas.md). Wrapping in our
                own RemoveScroll instance pushes it onto react-remove-scroll's lock
                stack, making *this* list the active lock while open so it scrolls
                normally — without opting into Popover's `modal` mode, which would
                focus-trap and aria-hide everything outside PopoverContent,
                including our search input (it lives in the anchor, not the content). */}
            <RemoveScroll allowPinchZoom>
              <CommandList className="[&::-webkit-scrollbar]:w-2.5">
                <CommandEmpty>No matches.</CommandEmpty>
                {groupNames.map((group) => (
                  <CommandGroup heading={group || undefined} key={group}>
                    {grouped[group].map((opt) => {
                      const checked = selected.has(opt.id);
                      return (
                        <CommandItem
                          key={opt.id}
                          value={`${opt.label} ${opt.sublabel ?? ""}`}
                          onSelect={() => onToggle(opt.id)}
                        >
                          <div
                            className={cn(
                              "flex h-4 w-4 shrink-0 items-center justify-center rounded-sm border",
                              checked ? "border-primary bg-primary text-primary-foreground" : "border-border",
                            )}
                          >
                            {checked && <Check className="h-3 w-3" />}
                          </div>
                          <div className="min-w-0 flex-1">
                            <p className="truncate">{opt.label}</p>
                            {opt.sublabel && (
                              <code className="text-xs text-muted-foreground break-all">{opt.sublabel}</code>
                            )}
                          </div>
                        </CommandItem>
                      );
                    })}
                  </CommandGroup>
                ))}
              </CommandList>
            </RemoveScroll>
          </PopoverContent>
        </Popover>
      </Command>

      {selectedOptions.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {selectedOptions.map((opt) => (
            <Badge className="gap-1 pr-1" key={opt.id} variant="secondary">
              {opt.label}
              <button
                aria-label={`Remove ${opt.label}`}
                className="rounded-full hover:bg-foreground/10"
                disabled={disabled}
                type="button"
                onClick={() => onToggle(opt.id)}
              >
                <X className="h-3 w-3" />
              </button>
            </Badge>
          ))}
        </div>
      )}
    </div>
  );
}
