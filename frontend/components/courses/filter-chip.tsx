"use client";

import Link from "next/link";
import { Check, ChevronDown } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { cn } from "@/lib/utils";

export interface FilterOption {
  label: string;
  href: string;
  active: boolean;
}

interface FilterChipProps {
  label: string;
  options: FilterOption[];
  /** True when a non-default option is selected; highlights the chip. */
  filtered: boolean;
}

// Dropdown-style chip: shows "Label: Value" and opens a menu of link options,
// so filter state stays in the URL (server-rendered results, shareable links).
export function FilterChip({ label, options, filtered }: FilterChipProps) {
  const current = options.find((o) => o.active);
  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        className={cn(
          "inline-flex min-h-9 shrink-0 items-center gap-1.5 rounded-full border px-3 text-xs font-medium capitalize transition-colors duration-fast",
          filtered
            ? "border-primary bg-primary/10 text-primary"
            : "border-border text-muted-foreground hover:bg-muted hover:text-foreground",
        )}
      >
        {filtered && current ? `${label}: ${current.label}` : label}
        <ChevronDown aria-hidden className="h-3.5 w-3.5" />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start">
        {options.map((o) => (
          <DropdownMenuItem asChild className="capitalize" key={o.label}>
            <Link href={o.href} replace scroll={false}>
              <span className="flex-1">{o.label}</span>
              {o.active && <Check aria-hidden className="ml-3 h-4 w-4 text-primary" />}
            </Link>
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
