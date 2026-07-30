"use client";

import { Check, BookOpen, ClipboardCheck, Dumbbell, Users, FileText, ShieldCheck, Layers, type LucideIcon } from "lucide-react";
import { Checkbox } from "@/components/ui/checkbox";
import { cn } from "@/lib/utils";

// Permission module → icon. Falls back to Layers for any module not in this
// fixed catalogue (see docs/rbac.md § Permission Catalogue). Exported so
// role-table.tsx can show the same per-module icon on its permission badges.
export const MODULE_ICONS: Record<string, LucideIcon> = {
  courses: BookOpen,
  assessments: ClipboardCheck,
  practice: Dumbbell,
  mentoring: Users,
  content: FileText,
  admin: ShieldCheck,
};

export function getModuleIcon(module: string): LucideIcon {
  return MODULE_ICONS[module] ?? Layers;
}

export interface ChecklistOption {
  id: string;
  label: string;
  sublabel?: string;
  group?: string;
}

interface ChecklistGridProps {
  options: ChecklistOption[];
  selected: Set<string>;
  onChange: (next: Set<string>) => void;
  disabled?: boolean;
}

function toggleOne(selected: Set<string>, id: string): Set<string> {
  const next = new Set(selected);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  return next;
}

function toggleMany(selected: Set<string>, ids: string[]): Set<string> {
  const next = new Set(selected);
  const allSelected = ids.every((id) => next.has(id));
  ids.forEach((id) => (allSelected ? next.delete(id) : next.add(id)));
  return next;
}

function OptionList({
  options,
  selected,
  onToggle,
  disabled,
}: {
  options: ChecklistOption[];
  selected: Set<string>;
  onToggle: (id: string) => void;
  disabled?: boolean;
}) {
  return (
    <div className="flex flex-col divide-y divide-border">
      {options.map((opt) => {
        const checked = selected.has(opt.id);
        return (
          <label
            aria-label={opt.sublabel ? `${opt.label} (${opt.sublabel})` : opt.label}
            className={cn(
              "relative block w-full min-w-0 px-6 py-3 pr-12 transition-colors focus-within:ring-2 focus-within:ring-ring focus-within:ring-offset-2 focus-within:ring-offset-background",
              disabled ? "cursor-default" : "cursor-pointer hover:bg-muted/50",
              checked && "bg-primary/5",
            )}
            htmlFor={`checklist-${opt.id}`}
            key={opt.id}
          >
            <input
              checked={checked}
              className="sr-only"
              disabled={disabled}
              id={`checklist-${opt.id}`}
              type="checkbox"
              onChange={() => onToggle(opt.id)}
            />
            <span
              aria-hidden="true"
              className={cn(
                "absolute top-3 right-6 flex h-5 w-5 items-center justify-center rounded-full border-2 transition-colors duration-fast ease-smooth",
                checked
                  ? "border-primary bg-primary text-primary-foreground"
                  : "border-border bg-background text-transparent",
              )}
            >
              <Check className="h-3 w-3" strokeWidth={3} />
            </span>
            <p className="font-medium text-sm truncate">{opt.label}</p>
            {opt.sublabel && <code className="text-xs text-muted-foreground break-all">{opt.sublabel}</code>}
          </label>
        );
      })}
    </div>
  );
}

// Flat list when no option carries a `group`. Grouped, module-sectioned
// layout with a per-group "select all" when they do (e.g. permission grid
// in admin/rbac/roles/[id]/page.tsx). This is the full-page editing grid —
// the compact dropdown case (manage-roles-dialog.tsx) uses
// MultiSelectDropdown (components/shared/multi-select-dropdown.tsx), a
// cmdk-backed combobox, instead of this component.
export function ChecklistGrid({ options, selected, onChange, disabled }: ChecklistGridProps) {
  const isGrouped = options.some((o) => o.group !== undefined);

  if (!isGrouped) {
    return (
      <div className="card-base p-0 rounded-sm">
        <OptionList
          disabled={disabled}
          options={options}
          selected={selected}
          onToggle={(id) => onChange(toggleOne(selected, id))}
        />
      </div>
    );
  }

  const grouped = options.reduce<Record<string, ChecklistOption[]>>((acc, opt) => {
    const key = opt.group ?? "";
    (acc[key] ??= []).push(opt);
    return acc;
  }, {});
  const groups = Object.keys(grouped).sort();

  return (
    <div className="grid-auto">
      {groups.map((group) => {
        const groupOptions = grouped[group];
        const ids = groupOptions.map((o) => o.id);
        const selectedCount = ids.filter((id) => selected.has(id)).length;
        const allSelected = selectedCount === ids.length;
        const someSelected = selectedCount > 0 && !allSelected;
        const ModuleIcon = getModuleIcon(group);
        return (
          <section className="mb-6 break-inside-avoid" key={group}>
            <h2 className="flex items-center gap-2 text-base font-semibold tracking-tight capitalize mb-3">
              <ModuleIcon aria-hidden className="h-4 w-4 text-muted-foreground" />
              {group}
            </h2>
            <div className="card-base p-0 rounded-sm">
              <div className="flex items-center justify-between gap-4 p-6 pb-4">
                <span className="text-sm text-muted-foreground">
                  {selectedCount}/{ids.length} selected
                </span>
                <div className="flex items-center gap-3">
                  <span className="text-sm font-medium">Select all</span>
                  <Checkbox
                    aria-label={`Select all ${group}`}
                    checked={allSelected ? true : someSelected ? "indeterminate" : false}
                    disabled={disabled}
                    onCheckedChange={() => onChange(toggleMany(selected, ids))}
                  />
                </div>
              </div>
              <OptionList
                disabled={disabled}
                options={groupOptions}
                selected={selected}
                onToggle={(id) => onChange(toggleOne(selected, id))}
              />
            </div>
          </section>
        );
      })}
    </div>
  );
}
