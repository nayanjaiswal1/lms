"use client";

import { parseAsStringLiteral, useQueryState } from "nuqs";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { RemoveMemberButton } from "@/app/(app)/batches/[id]/remove-member-button";
import { RemoveMentorButton } from "@/components/batches/remove-mentor-button";
import { UserLink } from "@/components/shared/user-link";

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
  actions?: React.ReactNode;
}

const ROLE_FILTERS = ["all", "member", "mentor"] as const;
const ROLE_FILTER_LABEL: Record<(typeof ROLE_FILTERS)[number], string> = {
  all:    "All roles",
  member: "Members",
  mentor: "Mentors",
};

export function PeopleList({ batchId, people, actions }: Props) {
  const [role, setRole] = useQueryState("role", parseAsStringLiteral(ROLE_FILTERS).withDefault("all"));

  const filtered = role === "all" ? people : people.filter((p) => p.role === role);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-3">
          <p className="text-sm text-muted-foreground">
            {filtered.length} {filtered.length === 1 ? "person" : "people"}
          </p>
          <Select value={role} onValueChange={(v) => void setRole(v as (typeof ROLE_FILTERS)[number])}>
            <SelectTrigger aria-label="Filter by role" className="h-8 w-32">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {ROLE_FILTERS.map((f) => (
                <SelectItem key={f} value={f}>{ROLE_FILTER_LABEL[f]}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        {actions}
      </div>

      {filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground py-6 text-center">No {ROLE_FILTER_LABEL[role].toLowerCase()} in this batch.</p>
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
                  <td className="py-2.5 pr-4 font-medium">
                    <UserLink className="hover:underline" userId={p.user_id}>
                      {p.name}
                    </UserLink>
                  </td>
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
