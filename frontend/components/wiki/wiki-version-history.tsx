"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { History, RotateCcw } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { apiFetch } from "@/lib/client/api";
import { restoreVersionAction } from "@/lib/wiki/actions";
import type { WikiPageVersionSummary } from "@/lib/server/wiki";

interface WikiVersionHistoryProps {
  pageId: string;
  canRestore: boolean;
}

export function WikiVersionHistory({ pageId, canRestore }: WikiVersionHistoryProps) {
  const router = useRouter();
  const [versions, setVersions] = useState<WikiPageVersionSummary[] | null>(null);
  const [restoringVersion, setRestoringVersion] = useState<number | null>(null);

  async function loadVersions() {
    if (versions) return;
    const data = await apiFetch<WikiPageVersionSummary[]>(`/wiki/pages/${pageId}/versions`);
    setVersions(data ?? []);
  }

  async function handleRestore(version: number) {
    setRestoringVersion(version);
    const result = await restoreVersionAction(pageId, version);
    setRestoringVersion(null);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't restore that version.");
      return;
    }
    toast.success(`Restored version ${version}`);
    setVersions(null);
    router.refresh();
  }

  return (
    <Sheet onOpenChange={(open) => open && void loadVersions()}>
      <SheetTrigger asChild>
        <Button size="sm" variant="outline">
          <History aria-hidden className="mr-2 h-4 w-4" />
          History
        </Button>
      </SheetTrigger>
      <SheetContent className="modal-responsive flex flex-col gap-4">
        <SheetHeader>
          <SheetTitle>Version history</SheetTitle>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto">
          {versions === null && <p className="text-sm text-muted-foreground">Loading…</p>}
          {versions?.length === 0 && <p className="text-sm text-muted-foreground">No earlier versions yet.</p>}
          {versions?.map((v) => (
            <div className="flex items-center justify-between gap-2 rounded-md border border-border px-3 py-2 text-sm" key={v.version}>
              <div className="min-w-0">
                <p className="truncate font-medium">Version {v.version} — {v.title}</p>
                <p className="text-xs text-muted-foreground">{new Date(v.saved_at).toLocaleString()}</p>
              </div>
              {canRestore && (
                <Button
                  className="shrink-0"
                  disabled={restoringVersion === v.version}
                  size="sm"
                  variant="ghost"
                  onClick={() => void handleRestore(v.version)}
                >
                  <RotateCcw aria-hidden className="mr-1.5 h-3.5 w-3.5" />
                  {restoringVersion === v.version ? "Restoring…" : "Restore"}
                </Button>
              )}
            </div>
          ))}
        </div>
      </SheetContent>
    </Sheet>
  );
}
