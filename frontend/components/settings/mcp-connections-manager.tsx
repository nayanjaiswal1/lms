"use client";

import { useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { Bot, Copy, ClipboardList, MoreVertical, History } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { revokeMcpConnectionAction } from "@/app/(app)/settings/integrations/actions";
import ROUTES from "@/lib/routes";

export interface McpConnection {
  id: string;
  client_id: string;
  client_name: string;
  scopes: string[];
  status: string;
  last_used_at: string | null;
  created_at: string;
}

function formatDate(iso: string | null): string {
  if (!iso) return "Never";
  return new Date(iso).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

interface McpConnectionsManagerProps {
  connections: McpConnection[];
  connectorUrl: string;
}

export function McpConnectionsManager({ connections, connectorUrl }: McpConnectionsManagerProps) {
  const [revokeTarget, setRevokeTarget] = useState<McpConnection | null>(null);

  async function copyConnectorUrl() {
    await navigator.clipboard.writeText(connectorUrl);
    toast.success("Connector URL copied.");
  }

  // No client (Claude, ChatGPT) lets a pasted chat message silently add a
  // connector on the user's behalf — that action is deliberately a manual,
  // explicit step in the client's own Settings UI, since it's the moment the
  // user grants account access. This copies the URL plus the manual steps so
  // there's nothing to remember or mistype; pasting it into a chat also works
  // fine as a way to have the assistant narrate the same steps back.
  //
  // Leads with Claude Desktop rather than Claude.ai/ChatGPT web: this URL is
  // whatever BACKEND_URL resolves to (localhost in dev), and only a client
  // running on this same machine — Desktop, or Claude Code itself — can
  // reach a localhost address. Claude.ai and ChatGPT are cloud products;
  // their servers call this URL directly and cannot reach your machine
  // without a public tunnel (ngrok, Cloudflare Tunnel) in front of it.
  async function copySetupGuide() {
    const guide = `Connect MindForge to Claude Desktop:

1. Open Claude Desktop -> Settings -> Connectors -> Add custom connector.
2. Paste this URL: ${connectorUrl}
3. Click Connect, sign in to MindForge if asked, then approve the requested access on the consent screen.
4. Once connected, just ask things like "what are my enrolled courses?" or "save a note on this lesson" and Claude will call MindForge directly.

Note: this URL only works from an app running on this same machine (Claude Desktop, Claude Code). Claude.ai and ChatGPT run in the cloud and can't reach a localhost address — connecting those needs a public tunnel in front of this server instead.`;
    await navigator.clipboard.writeText(guide);
    toast.success("Setup guide copied.");
  }

  async function handleRevoke() {
    if (!revokeTarget) return;
    const target = revokeTarget;
    setRevokeTarget(null);
    const result = await revokeMcpConnectionAction(target.id);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`Disconnected from ${target.client_name}.`);
  }

  return (
    <section aria-labelledby="mcp-connections-heading" className="card-base p-6 space-y-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-foreground" id="mcp-connections-heading">
            Connect your own Claude or ChatGPT
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Add MindForge as a connector in your own Claude or ChatGPT account. It can read your
            enrolled courses and lesson content, save notes and log what you understood, and — if
            you allow it — view, create, update, and delete events on your calendar, all with your
            approval below.
          </p>
        </div>
        <Button asChild size="sm" variant="outline">
          <Link href={ROUTES.SETTINGS_INTEGRATIONS_ACTIVITY}>
            <History aria-hidden className="mr-1.5 h-3.5 w-3.5" />
            Activity log
          </Link>
        </Button>
      </div>

      <div className="ai-surface rounded-lg p-4 space-y-2">
        <p className="text-xs font-semibold text-ai">Connector URL</p>
        <div className="flex items-center gap-2">
          <code className="flex-1 truncate rounded-md bg-background px-3 py-2 text-xs">{connectorUrl}</code>
          <Button aria-label="Copy connector URL" className="touch-target" onClick={copyConnectorUrl} size="icon" variant="outline">
            <Copy aria-hidden className="h-4 w-4" />
          </Button>
        </div>
        <p className="text-xs text-muted-foreground">
          Paste this into your client&apos;s connector settings (e.g. Claude.ai → Settings → Connectors → Add custom connector). You&apos;ll be asked to sign in and approve access here before it can connect.
        </p>
        <Button className="w-full sm:w-auto" onClick={copySetupGuide} size="sm" variant="outline">
          <ClipboardList aria-hidden className="mr-2 h-3.5 w-3.5" />
          Copy setup guide
        </Button>
      </div>

      {connections.length === 0 ? (
        <p className="text-sm text-muted-foreground empty-state py-6">
          No connections yet.
        </p>
      ) : (
        <ul className="divide-y divide-border">
          {connections.map((conn) => (
            <li className="flex items-center justify-between gap-4 py-3" key={conn.id}>
              <div className="min-w-0 flex items-center gap-3">
                <Bot aria-hidden className="h-8 w-8 flex-shrink-0 text-ai" />
                <div className="min-w-0">
                  <p className="text-sm font-medium text-foreground truncate">{conn.client_name}</p>
                  <p className="text-xs text-muted-foreground">
                    Connected {formatDate(conn.created_at)} · Last used {formatDate(conn.last_used_at)}
                  </p>
                  <div className="mt-1 flex flex-wrap gap-1">
                    {conn.scopes.map((scope) => (
                      <Badge key={scope} variant="secondary">{scope}</Badge>
                    ))}
                  </div>
                </div>
              </div>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button aria-label={`Manage ${conn.client_name}`} className="touch-target" size="icon" variant="ghost">
                    <MoreVertical aria-hidden className="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem
                    className="text-destructive focus:text-destructive"
                    onSelect={() => setRevokeTarget(conn)}
                  >
                    Disconnect
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </li>
          ))}
        </ul>
      )}

      <AlertDialog open={revokeTarget !== null} onOpenChange={(open) => !open && setRevokeTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Disconnect {revokeTarget?.client_name}?</AlertDialogTitle>
            <AlertDialogDescription>
              It will immediately lose access to your courses and notes. You can reconnect it later from its own connector settings.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={handleRevoke}
            >
              Disconnect
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </section>
  );
}
