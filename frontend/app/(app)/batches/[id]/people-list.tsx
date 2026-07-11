"use client";

import { parseAsStringLiteral, useQueryState } from "nuqs";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { RemoveMemberButton } from "@/app/(app)/batches/[id]/remove-member-button";
import { RemoveMentorButton } from "@/components/batches/remove-mentor-button";

export interface Person {
  user_id: string;
  name: string;
  email: string;
  added_at: string;
  role: "member" | "mentor";
}

interface Props {
  batchId: string;
  people: Person[];
}

const ROLE_FILTERS = ["all", "member", "mentor"] as const;
const ROLE_FILTER_LABEL: Record<(typeof ROLE_FILTERS)[number], string> = {
  all:    "All",
  member: "Members",
  mentor: "Mentors",
};

export function PeopleList({ batchId, people }: Props) {
  const [role, setRole] = useQueryState("role", parseAsStringLiteral(ROLE_FILTERS).withDefault("all"));

  const filtered = role === "all" ? people : people.filter((p) => p.role === role);

  return (
    <div className="flex flex-col gap-4">
      <div aria-label="Role filter" className="flex gap-1 border-b border-border" role="tablist">
        {ROLE_FILTERS.map((f) => {
          const isActive = f === role;
          return (
            <button
              aria-selected={isActive}
              className={cn(
                "px-3 py-2 text-sm font-medium border-b-2 transition-colors duration-fast",
                isActive
                  ? "text-primary border-primary"
                  : "text-muted-foreground border-transparent hover:text-foreground hover:border-border",
              )}
              key={f}
              role="tab"
              type="button"
              onClick={() => void setRole(f)}
            >
              {ROLE_FILTER_LABEL[f]}
            </button>
          );
        })}
      </div>

      {filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground py-6 text-center">No {role === "all" ? "people" : ROLE_FILTER_LABEL[role].toLowerCase()} match this filter.</p>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="pb-2 font-medium">Name</th>
                <th className="pb-2 font-medium">Email</th>
                <th className="pb-2 font-medium">Role</th>
                <th className="pb-2 font-medium">Joined</th>
                <th className="pb-2 font-medium sr-only">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {filtered.map((p) => (
                <tr key={`${p.role}-${p.user_id}`}>
                  <td className="py-2.5 pr-4 font-medium">{p.name}</td>
                  <td className="py-2.5 pr-4 text-muted-foreground">{p.email}</td>
                  <td className="py-2.5 pr-4">
                    <Badge variant={p.role === "mentor" ? "default" : "secondary"}>
                      {p.role === "mentor" ? "Mentor" : "Member"}
                    </Badge>
                  </td>
                  <td className="py-2.5 pr-4 text-muted-foreground">
                    {new Date(p.added_at).toLocaleDateString()}
                  </td>
                  <td className="py-2.5 text-right">
                    {p.role === "mentor" ? (
                      <RemoveMentorButton batchId={batchId} userId={p.user_id} userName={p.name} />
                    ) : (
                      <RemoveMemberButton batchId={batchId} userId={p.user_id} userName={p.name} />
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
