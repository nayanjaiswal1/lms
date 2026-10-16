"use client";

import { parseAsString, useQueryState } from "nuqs";
import { Search, SearchX } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { MentorDirectoryCard } from "@/components/mentoring/mentor-directory-card";
import type { MentorDirectoryEntry } from "@/lib/server/mentoring";
import { cn } from "@/lib/utils";

const MAX_SKILL_CHIPS = 12;

interface MentorDirectoryProps {
  mentors: MentorDirectoryEntry[];
  // user_id → assigned ticket id, for mentors the student can already chat with.
  chatTicketByMentor: Record<string, string>;
}

// Most-shared skills first: the chips are a shortcut to the common filters,
// the free-text search still reaches every long-tail skill.
function topSkills(mentors: MentorDirectoryEntry[]): string[] {
  const counts = new Map<string, { label: string; count: number }>();
  for (const skill of mentors.flatMap((m) => m.skills)) {
    const key = skill.toLowerCase();
    const entry = counts.get(key);
    counts.set(key, { label: entry?.label ?? skill, count: (entry?.count ?? 0) + 1 });
  }
  return [...counts.values()]
    .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label))
    .slice(0, MAX_SKILL_CHIPS)
    .map((s) => s.label);
}

function matches(mentor: MentorDirectoryEntry, query: string, skill: string): boolean {
  const skills = mentor.skills.map((s) => s.toLowerCase());
  if (skill && !skills.includes(skill)) return false;
  if (!query) return true;
  return [mentor.name, mentor.current_role ?? "", ...skills].some((field) => field.toLowerCase().includes(query));
}

export function MentorDirectory({ mentors, chatTicketByMentor }: MentorDirectoryProps) {
  const [query, setQuery] = useQueryState("q", parseAsString.withDefault(""));
  const [skill, setSkill] = useQueryState("skill", parseAsString.withDefault(""));

  const needle = query.trim().toLowerCase();
  const visible = mentors.filter((m) => matches(m, needle, skill));
  const skillChips = topSkills(mentors);
  const filtered = needle !== "" || skill !== "";

  function clearFilters() {
    void setQuery(null);
    void setSkill(null);
  }

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-col gap-3">
        <div className="relative w-full sm:max-w-md">
          <Search
            aria-hidden
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
          />
          <Input
            aria-label="Search mentors by name, role or skill"
            className="pl-9"
            placeholder="Search by name, role or skill"
            type="search"
            value={query}
            onChange={(e) => void setQuery(e.target.value || null)}
          />
        </div>

        {skillChips.length > 0 && (
          <fieldset className="flex min-w-0 flex-wrap gap-2">
            <legend className="sr-only">Filter by expertise</legend>
            {skillChips.map((label) => {
              const key = label.toLowerCase();
              const active = skill === key;
              return (
                <Button
                  aria-pressed={active}
                  className={cn(
                    "touch-target-dense rounded-full border px-3 py-1 text-sm transition-colors duration-fast ease-smooth",
                    active
                      ? "border-primary bg-primary text-primary-foreground"
                      : "border-border bg-background text-foreground hover:border-primary/50 hover:bg-primary/5",
                  )}
                  key={key}
                  type="button"
                  variant="unstyled"
                  onClick={() => void setSkill(active ? null : key)}
                >
                  {label}
                </Button>
              );
            })}
          </fieldset>
        )}

        <p aria-live="polite" className="text-sm text-muted-foreground">
          {filtered
            ? `${visible.length} of ${mentors.length} mentor${mentors.length === 1 ? "" : "s"}`
            : `${mentors.length} mentor${mentors.length === 1 ? "" : "s"} in your organization`}
        </p>
      </div>

      {visible.length === 0 ? (
        <div className="empty-state rounded-xl border border-dashed border-border">
          <SearchX aria-hidden className="empty-state-icon" />
          <p className="text-sm">No mentors match those filters.</p>
          <Button className="min-h-11 lg:min-h-9" variant="outline" onClick={clearFilters}>
            Clear filters
          </Button>
        </div>
      ) : (
        <ul className="card-grid">
          {visible.map((mentor) => (
            <li key={mentor.user_id}>
              <MentorDirectoryCard
                activeSkill={skill}
                chatTicketId={chatTicketByMentor[mentor.user_id]}
                mentor={mentor}
              />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
