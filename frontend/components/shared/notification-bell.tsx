"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Bell } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { apiFetch } from "@/lib/client/api";
import { cn } from "@/lib/utils";
import type { ListView, Notification, UnreadCountView } from "@/lib/notifications/types";

const POLL_INTERVAL_MS = 60_000;

function relativeTime(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diffMs / 60_000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d ago`;
  return new Date(iso).toLocaleDateString();
}

interface ListState {
  status: "idle" | "loading" | "loaded";
  items: Notification[];
}

// Bell icon + unread badge, mounted once in the app shell (desktop sidebar
// and mobile header — see components/layout/sidebar.tsx / mobile-nav.tsx).
// Polls GET /api/notifications/unread-count every 60s per
// kind-herding-cookie.md §0.6's deliberate polling-over-SSE/WebSocket call —
// the same setInterval-in-useEffect shape as EvalPoller/LabProvisioningWatcher,
// the codebase's existing pattern for a client-side timer.
export function NotificationBell() {
  const router = useRouter();
  const [unreadCount, setUnreadCount] = React.useState(0);
  const [list, setList] = React.useState<ListState>({ status: "idle", items: [] });

  React.useEffect(() => {
    let cancelled = false;
    async function poll() {
      const res = await apiFetch<UnreadCountView>("/notifications/unread-count");
      if (!cancelled && res) setUnreadCount(res.unread_count);
    }
    void poll();
    const id = setInterval(() => void poll(), POLL_INTERVAL_MS);
    return () => {
      cancelled = true;
      clearInterval(id);
    };
  }, []);

  async function handleOpenChange(open: boolean) {
    if (!open || list.status !== "idle") return;
    setList((s) => ({ ...s, status: "loading" }));
    const res = await apiFetch<ListView>("/notifications");
    setList({ status: "loaded", items: res?.notifications ?? [] });
  }

  function handleSelect(n: Notification) {
    if (!n.read_at) {
      setUnreadCount((c) => Math.max(0, c - 1));
      setList((s) => ({
        ...s,
        items: s.items.map((item) =>
          item.id === n.id ? { ...item, read_at: new Date().toISOString() } : item,
        ),
      }));
      // Best-effort: the click's real job is to follow link_url below — a
      // failed mark-read isn't worth blocking navigation or a toast for.
      void apiFetch(`/notifications/${n.id}/read`, { method: "POST" });
    }
    if (n.link_url) router.push(n.link_url);
  }

  function handleMarkAllRead() {
    setUnreadCount(0);
    setList((s) => ({
      ...s,
      items: s.items.map((item) => ({ ...item, read_at: item.read_at ?? new Date().toISOString() })),
    }));
    void apiFetch("/notifications/read-all", { method: "POST" });
  }

  return (
    <DropdownMenu onOpenChange={(open) => void handleOpenChange(open)}>
      <DropdownMenuTrigger asChild>
        <Button
          aria-label={unreadCount > 0 ? `Notifications, ${unreadCount} unread` : "Notifications"}
          className="relative touch-target"
          size="icon"
          variant="ghost"
        >
          <Bell aria-hidden className="h-4 w-4" />
          {unreadCount > 0 && (
            <span className="absolute -right-1 -top-1 z-raised flex h-4 min-w-4 items-center justify-center rounded-full bg-primary px-1 text-[10px] font-semibold leading-none text-primary-foreground">
              {unreadCount > 99 ? "99+" : unreadCount}
            </span>
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-80" sideOffset={8}>
        <div className="flex items-center justify-between px-2 py-1.5">
          <DropdownMenuLabel className="p-0 text-sm font-normal">Notifications</DropdownMenuLabel>
          {unreadCount > 0 && (
            <button
              className="text-xs font-medium text-primary hover:underline"
              type="button"
              onClick={handleMarkAllRead}
            >
              Mark all read
            </button>
          )}
        </div>
        <DropdownMenuSeparator />
        <div className="max-h-96 overflow-y-auto">
          {list.status === "loading" && (
            <p className="px-2 py-6 text-center text-sm text-muted-foreground">Loading…</p>
          )}
          {list.status === "loaded" && list.items.length === 0 && (
            <p className="px-2 py-6 text-center text-sm text-muted-foreground">You&apos;re all caught up.</p>
          )}
          {list.items.map((n) => (
            <DropdownMenuItem
              className={cn("flex flex-col items-start gap-0.5 whitespace-normal py-2", !n.read_at && "bg-accent/40")}
              key={n.id}
              onSelect={() => handleSelect(n)}
            >
              <span className="text-sm font-medium text-foreground">{n.title}</span>
              {n.body && <span className="line-clamp-2 text-xs text-muted-foreground">{n.body}</span>}
              <span className="text-xs text-muted-foreground">{relativeTime(n.created_at)}</span>
            </DropdownMenuItem>
          ))}
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
