import { Badge } from "@/components/ui/badge";
import { UserLink } from "@/components/shared/user-link";
import type { AuditEntry } from "@/app/(app)/users/[id]/types";

const ACTION_BADGE: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  "role.create": "default",
  "user.role.assign": "default",
  "user.role.revoke": "destructive",
  "user.permission.grant": "default",
  "user.permission.revoke": "destructive",
  "user.status.update": "outline",
};

export function AuditTab({ entries }: { entries: AuditEntry[] }) {
  if (entries.length === 0) {
    return (
      <div className="empty-state">
        <p>No audit entries for this user yet.</p>
      </div>
    );
  }

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-muted-foreground whitespace-nowrap">
            <th className="pb-2 pr-4 font-medium">When</th>
            <th className="pb-2 pr-4 font-medium">Action</th>
            <th className="pb-2 font-medium">Actor</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((e) => (
            <tr className="border-b border-border last:border-0 align-top" key={e.id}>
              <td className="py-3 pr-4 text-muted-foreground whitespace-nowrap">
                {new Date(e.created_at).toLocaleString()}
              </td>
              <td className="py-3 pr-4 whitespace-nowrap">
                <Badge variant={ACTION_BADGE[e.action] ?? "outline"}>{e.action}</Badge>
                {e.diff && (
                  <details className="mt-1.5">
                    <summary className="cursor-pointer text-xs text-primary">diff</summary>
                    <pre className="mt-1 max-w-md whitespace-pre-wrap break-all rounded-md bg-muted p-2 text-xs text-muted-foreground">
                      {JSON.stringify(e.diff, null, 2)}
                    </pre>
                  </details>
                )}
              </td>
              <td className="py-3 text-muted-foreground text-xs whitespace-nowrap">
                {e.actor_id ? (
                  <UserLink className="hover:text-foreground hover:underline" userId={e.actor_id}>
                    <span title={e.actor_id}>{e.actor_name ?? e.actor_email ?? e.actor_id}</span>
                  </UserLink>
                ) : (
                  <span className="italic">system</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
