import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getAuditLogs } from "@/lib/server/orgs";
import type { AuditLog } from "@/lib/orgs/types";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Audit Log — Organisation Settings",
};

async function getCurrentOrgId(): Promise<string | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString(),
    ) as { org_id?: string };
    return payload.org_id ?? null;
  } catch {
    return null;
  }
}

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
      {/* Timeline indicator */}
      <div className="flex flex-col items-center gap-1 flex-shrink-0 pt-0.5">
        <div className="h-2 w-2 rounded-full bg-border mt-1" />
        <div className="w-px flex-1 bg-border" />
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 pb-2">
        <div className="flex flex-wrap items-center gap-2 mb-1">
          <Badge variant={actionBadgeVariant(log.action)}>
            {actionLabel(log.action)}
          </Badge>
          {log.target_type && (
            <span className="text-xs text-muted-foreground">
              {log.target_type}
              {log.target_id && (
                <span className="font-mono ml-1 text-foreground">#{log.target_id.slice(0, 8)}</span>
              )}
            </span>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-3 mt-1">
          <span className="text-xs text-muted-foreground">
            Actor:{" "}
            <span className="text-foreground font-medium">
              {log.actor_user_id ? log.actor_user_id.slice(0, 8) : "System"}
            </span>
          </span>
          <span className="text-xs text-muted-foreground">
            {log.ip_address && `IP: ${log.ip_address} ·`}{" "}
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
  searchParams: Promise<{ cursor?: string }>;
}) {
  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const { cursor } = await searchParams;
  const logPage = await getAuditLogs(orgId, cursor);
  const { logs, next_cursor } = logPage;

  return (
    <div className="space-y-6">
      <div className="card-base p-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="text-lg font-semibold text-foreground">Audit Log</h2>
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

            {next_cursor && (
              <div className="pt-4 flex justify-center">
                <Button asChild variant="secondary">
                  <Link href={`?cursor=${encodeURIComponent(next_cursor)}`}>
                    Load more
                  </Link>
                </Button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
