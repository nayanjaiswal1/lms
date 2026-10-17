import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { UserLink } from "@/components/shared/user-link";
import { getAuditLogs } from "@/lib/orgs/server";
import type { AuditLog } from "@/lib/orgs/types";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";

export const dynamic = "force-dynamic";

const PAGE_SIZE = 25;

export const metadata: Metadata = {
  title: "Audit Log — Organisation Settings",
};


function actionBadgeVariant(action: string): "default" | "secondary" | "destructive" | "outline" {
  if (action.startsWith("create") || action.startsWith("invite")) return "default";
  if (action.startsWith("delete") || action.startsWith("remove") || action.startsWith("revoke")) return "destructive";
  if (action.startsWith("update") || action.startsWith("patch")) return "secondary";
  return "outline";
}

function formatRelativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d ago`;
  return new Date(iso).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function actionLabel(action: string): string {
  return action.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

function AuditLogEntry({ log }: { log: AuditLog }) {
  return (
    <div className="flex gap-4 py-4 border-b border-border last:border-0">
      <div className="flex flex-col items-center gap-1 flex-shrink-0 pt-0.5">
        <div className="h-2 w-2 rounded-full bg-border mt-1" />
        <div className="w-px flex-1 bg-border" />
      </div>

      <div className="flex-1 min-w-0 pb-2">
        <div className="flex flex-wrap items-center gap-2 mb-1">
          <Badge variant={actionBadgeVariant(log.action)}>
            {actionLabel(log.action)}
          </Badge>
          {log.entity_type && (
            <span className="text-xs text-muted-foreground">
              {log.entity_type}
              {log.entity_id && (
                <span className="font-mono ml-1 text-foreground">#{log.entity_id.slice(0, 8)}</span>
              )}
            </span>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-3 mt-1">
          <span className="text-xs text-muted-foreground">
            Actor:{" "}
            {log.actor_id ? (
              <UserLink className="text-foreground font-medium" userId={log.actor_id}>
                {log.actor_name ?? log.actor_email ?? log.actor_id.slice(0, 8)}
              </UserLink>
            ) : (
              <span className="text-foreground font-medium">System</span>
            )}
          </span>
          <span className="text-xs text-muted-foreground">
            {formatRelativeTime(log.created_at)}
          </span>
        </div>
      </div>
    </div>
  );
}

export default async function AuditLogPage({
  searchParams,
}: {
  searchParams: Promise<{ offset?: string }>;
}) {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.ADMIN.VIEW_AUDIT_LOG)) {
    notFound();
  }

  const { offset: rawOffset } = await searchParams;
  const offset = Math.max(0, Number(rawOffset) || 0);
  const { entries: logs, total } = await getAuditLogs(offset, PAGE_SIZE);

  return (
    <div className="space-y-6">
      <div className="card-base p-6">
        <div className="flex-between mb-6">
          <div>
            <h2 className="subsection-title text-foreground">Audit Log</h2>
            <p className="text-sm text-muted-foreground">
              A record of all actions taken within your organisation.
            </p>
          </div>
        </div>

        {logs.length === 0 ? (
          <div className="empty-state py-12">
            <p className="text-sm text-muted-foreground">No audit events recorded yet.</p>
          </div>
        ) : (
          <div>
            {logs.map((log) => (
              <AuditLogEntry key={log.id} log={log} />
            ))}

            <div className="flex justify-center gap-2 pt-4">
              {offset > 0 && (
                <Button asChild variant="outline">
                  <Link href={`?offset=${Math.max(0, offset - PAGE_SIZE)}`}>Newer</Link>
                </Button>
              )}
              {offset + PAGE_SIZE < total && (
                <Button asChild variant="outline">
                  <Link href={`?offset=${offset + PAGE_SIZE}`}>Older</Link>
                </Button>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
