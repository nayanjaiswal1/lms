"use client";

import { parseAsStringLiteral, useQueryState } from "nuqs";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

export const ROLE_TYPE_FILTERS = ["all", "system", "custom"] as const;
const ROLE_TYPE_FILTER_LABEL: Record<(typeof ROLE_TYPE_FILTERS)[number], string> = {
  all: "All types",
  system: "System",
  custom: "Custom",
};

export const ROLE_STATUS_FILTERS = ["all", "active", "disabled"] as const;
const ROLE_STATUS_FILTER_LABEL: Record<(typeof ROLE_STATUS_FILTERS)[number], string> = {
  all: "All statuses",
  active: "Active",
  disabled: "Disabled",
};

// The full role list is already fetched in one page.tsx round-trip (roles
// are a small, bounded set, unlike users) — search/type/status all filter
// client-side against that same list, read back out in role-table.tsx via
// the same URL params so the two stay in sync without prop drilling.
export function RoleFilters() {
  const [type, setType] = useQueryState("type", parseAsStringLiteral(ROLE_TYPE_FILTERS).withDefault("all"));
  const [status, setStatus] = useQueryState(
    "status",
    parseAsStringLiteral(ROLE_STATUS_FILTERS).withDefault("all"),
  );

  return (
    <>
      <Select value={type} onValueChange={(v) => void setType(v as (typeof ROLE_TYPE_FILTERS)[number])}>
        <SelectTrigger aria-label="Filter by type" className="h-9 w-full sm:w-36">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {ROLE_TYPE_FILTERS.map((f) => (
            <SelectItem key={f} value={f}>
              {ROLE_TYPE_FILTER_LABEL[f]}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      <Select value={status} onValueChange={(v) => void setStatus(v as (typeof ROLE_STATUS_FILTERS)[number])}>
        <SelectTrigger aria-label="Filter by status" className="h-9 w-full sm:w-36">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {ROLE_STATUS_FILTERS.map((f) => (
            <SelectItem key={f} value={f}>
              {ROLE_STATUS_FILTER_LABEL[f]}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </>
  );
}
