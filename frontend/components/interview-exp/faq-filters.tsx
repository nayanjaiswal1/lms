"use client";

import { parseAsString, parseAsStringLiteral, useQueryState } from "nuqs";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

const STATUS_FILTERS = ["all", "todo", "done", "revisit"] as const;

export function FaqFilters() {
  const [company, setCompany] = useQueryState("company", parseAsString.withDefault(""));
  const [tag, setTag] = useQueryState("tag", parseAsString.withDefault(""));
  const [status, setStatus] = useQueryState("status", parseAsStringLiteral(STATUS_FILTERS).withDefault("all"));

  return (
    <div className="stack-sm">
      <Input
        aria-label="Filter by company"
        placeholder="Company"
        value={company}
        onChange={(e) => setCompany(e.target.value || null)}
      />
      <Input
        aria-label="Filter by tag"
        placeholder="Tag (e.g. react)"
        value={tag}
        onChange={(e) => setTag(e.target.value || null)}
      />
      <Select value={status} onValueChange={(v) => setStatus(v as typeof STATUS_FILTERS[number])}>
        <SelectTrigger aria-label="Filter by status" className="sm:w-40">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="all">All statuses</SelectItem>
          <SelectItem value="todo">Todo</SelectItem>
          <SelectItem value="done">Done</SelectItem>
          <SelectItem value="revisit">Revisit</SelectItem>
        </SelectContent>
      </Select>
    </div>
  );
}
