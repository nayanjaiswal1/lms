"use client";

import * as React from "react";
import Link from "next/link";
import { Sparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { apiFetch } from "@/lib/client/api";
import { WHATS_NEW_ICON_MAP, type WhatsNewEntry } from "@/lib/whats-new";
import { cn } from "@/lib/utils";

const SEEN_KEY = "mf-whats-new-seen";

// Module-level singleton, same rationale as <NotificationBell>
// (components/shared/notification-bell.tsx): this trigger is mounted twice
// at once (desktop sidebar + mobile header), so the fetch is shared instead
// of duplicated. Unlike notifications there's no polling — release notes
// don't change mid-session, so one fetch on first mount is enough.
interface ListState {
  status: "idle" | "loading" | "loaded";
  entries: WhatsNewEntry[];
}
let sharedList: ListState = { status: "idle", entries: [] };
const listeners = new Set<() => void>();

function notifyListeners() {
  listeners.forEach((l) => l());
}

async function loadEntries() {
  if (sharedList.status !== "idle") return;
  sharedList = { ...sharedList, status: "loading" };
  const res = await apiFetch<{ entries: WhatsNewEntry[] }>("/whats-new");
  sharedList = { status: "loaded", entries: res?.entries ?? [] };
  notifyListeners();
}

function subscribeList(listener: () => void): () => void {
  listeners.add(listener);
  void loadEntries();
  return () => listeners.delete(listener);
}

function getListSnapshot(): ListState {
  return sharedList;
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, { day: "numeric", month: "long", year: "numeric" });
}

export function WhatsNewDialog() {
  const list = React.useSyncExternalStore(subscribeList, getListSnapshot, () => sharedList);
  const [hasUnseen, setHasUnseen] = React.useState(false);
  const [selectedId, setSelectedId] = React.useState<string>();
  const latestId = list.entries[0]?.id;

  // Read after mount, same reason as sidebar.tsx's collapsed-state effect:
  // localStorage isn't available during SSR, so comparing on the server
  // would mismatch the client's first render.
  React.useEffect(() => {
    if (latestId) setHasUnseen(localStorage.getItem(SEEN_KEY) !== latestId);
  }, [latestId]);

  function handleOpenChange(open: boolean) {
    if (!open || !latestId) return;
    localStorage.setItem(SEEN_KEY, latestId);
    setHasUnseen(false);
    setSelectedId(latestId);
  }

  if (list.status === "loaded" && list.entries.length === 0) return null;
  const selected = list.entries.find((e) => e.id === selectedId) ?? list.entries[0];
  const SelectedIcon = selected ? (WHATS_NEW_ICON_MAP[selected.icon] ?? Sparkles) : Sparkles;

  return (
    <Dialog onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button aria-label="What's new" className="relative touch-target" size="icon" variant="ghost">
          <Sparkles aria-hidden className="h-4 w-4" />
          {hasUnseen && <span className="absolute right-1 top-1 z-raised h-2 w-2 rounded-full bg-primary" />}
        </Button>
      </DialogTrigger>
      {selected && (
        <DialogContent className="modal-responsive gap-0 overflow-hidden p-0 sm:max-w-2xl">
          <DialogTitle className="sr-only">What&apos;s new</DialogTitle>
          <DialogDescription className="sr-only">Recent MindForge feature releases</DialogDescription>
          <div className="flex h-full flex-col sm:max-h-[85dvh] sm:flex-row">
            <div className="shrink-0 border-b border-border sm:w-52 sm:border-b-0 sm:border-r">
              <div className="p-4 pb-3">
                <p className="text-sm font-semibold text-foreground">What&apos;s new</p>
                <p className="text-xs text-muted-foreground">You asked. We built it.</p>
              </div>
              <div className="flex gap-1 overflow-x-auto px-2 pb-2 sm:flex-col sm:overflow-y-auto sm:px-2 sm:pb-4">
                {list.entries.map((entry) => (
                  <button
                    className={cn(
                      "shrink-0 rounded-md px-3 py-2 text-left transition-colors duration-fast sm:shrink",
                      entry.id === selected.id ? "bg-accent text-accent-foreground" : "hover:bg-accent/50",
                    )}
                    key={entry.id}
                    type="button"
                    onClick={() => setSelectedId(entry.id)}
                  >
                    <span className="block whitespace-nowrap text-sm font-medium sm:whitespace-normal">
                      {entry.title}
                    </span>
                    <span className="block text-xs text-muted-foreground">{formatDate(entry.published_at)}</span>
                  </button>
                ))}
              </div>
            </div>

            <div className="flex flex-1 flex-col overflow-y-auto p-6">
              <div className="mb-5 flex h-40 items-center justify-center rounded-lg bg-muted">
                <SelectedIcon aria-hidden className="h-14 w-14 text-primary" />
              </div>
              <h2 className="text-lg font-semibold text-foreground">{selected.title}</h2>
              <p className="mt-2 flex-1 text-sm text-muted-foreground">{selected.description}</p>
              <Button asChild className="mt-4 w-fit">
                <Link href={selected.cta_href}>{selected.cta_label}</Link>
              </Button>
            </div>
          </div>
        </DialogContent>
      )}
    </Dialog>
  );
}
