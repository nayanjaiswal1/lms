"use client";

import { X } from "lucide-react";
import { parseAsStringLiteral, useQueryState } from "nuqs";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ORG_MEMBER_STATUS_OPTIONS } from "@/lib/constants";
import type { RoleOption } from "@/app/(app)/users/user-table";

export const STATUS_FILTERS = ["all", ...ORG_MEMBER_STATUS_OPTIONS.map((o) => o.value)] as const;
export const STATUS_FILTER_LABEL: Record<(typeof STATUS_FILTERS)[number], string> = {
  all: "All statuses",
  ...Object.fromEntries(ORG_MEMBER_STATUS_OPTIONS.map((o) => [o.value, o.label])),
} as Record<(typeof STATUS_FILTERS)[number], string>;

interface Props {
  roleOptions: RoleOption[];
}

// Lives in the same toolbar row as the search input, next to the role
// legend. Reads/writes the `status`/`role` URL params — UserTable reads the
// same params (via nuqs, which keeps every subscriber in sync) to filter.
export function UserFilters({ roleOptions }: Props) {
  const [status, setStatus] = useQueryState(
    "status",
    parseAsStringLiteral(STATUS_FILTERS).withDefault("all"),
  );
  // Value is the role NAME, not its id — `UserSummary.role_names` (user-table.tsx)
  // only exposes names per user row, so that's the only thing this filter can match against.
  const [roleName, setRoleName] = useQueryState("role", { defaultValue: "all" });
  const hasActiveFilters = status !== "all" || roleName !== "all";

  function clearFilters() {
    void setStatus("all");
    void setRoleName("all");
  }

  return (
    <>
      {/* h-11 matches the search Input next to it — the Select primitive's
          own default is h-10, and this row previously clipped it to h-9,
          leaving three controls in one row at three different heights. */}
      <Select value={status} onValueChange={(v) => void setStatus(v as (typeof STATUS_FILTERS)[number])}>
        <SelectTrigger aria-label="Filter by status" className="h-11 w-full sm:w-40">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {STATUS_FILTERS.map((f) => (
            <SelectItem key={f} value={f}>
              {STATUS_FILTER_LABEL[f]}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      <Select value={roleName} onValueChange={(v) => void setRoleName(v)}>
        <SelectTrigger aria-label="Filter by role" className="h-11 w-full sm:w-40">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="all">All roles</SelectItem>
          {roleOptions.map((r) => (
            <SelectItem key={r.id} value={r.name}>
              {r.name.replace("_", " ")}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      {hasActiveFilters && (
        <Button aria-label="Clear filters" className="gap-1" size="sm" variant="ghost" onClick={clearFilters}>
          <X aria-hidden className="h-3.5 w-3.5" />
          Clear
        </Button>
      )}
    </>
  );
}
