"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Sparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import { CreateItemDialog } from "@/components/workspace/items/create-item-dialog";
import { changeImpactAction, explainLateAction, suggestTaskBreakdownAction } from "@/lib/workspace/phase5-actions";
import { useIdempotencyKey } from "@/hooks/use-idempotency-key";
import type { ItemDetail, SuggestedItem, Track } from "@/lib/workspace/types";

type AIResult =
  | { kind: "breakdown"; items: SuggestedItem[] }
  | { kind: "why-late"; text: string }
  | { kind: "change-impact"; text: string; affectedCount: number };

interface AIToolsPanelProps {
  workspaceId: string;
  item: ItemDetail;
  tracks: Track[];
  canManage: boolean;
}

/** contract-phase5.md 5c: manager+/track-lead only, feature-scoped AI tools —
 * task breakdown, "why is this late", and change impact. Every result is
 * suggest-only text/data; "Create" per breakdown suggestion still goes
 * through CreateItemDialog's normal create path. */
export function AIToolsPanel({ workspaceId, item, tracks, canManage }: AIToolsPanelProps) {
  const [result, setResult] = useState<AIResult | null>(null);
  const [pending, startTransition] = useTransition();
  const withKey = useIdempotencyKey();

  if (!canManage || item.type !== "feature") return null;

  function run(kind: AIResult["kind"]) {
    startTransition(async () => {
      if (kind === "breakdown") {
        const r = await withKey((key) => suggestTaskBreakdownAction(workspaceId, item.id, key));
        if (r.error) { toast.error(r.error); return; }
        setResult({ kind: "breakdown", items: r.data?.items ?? [] });
      } else if (kind === "why-late") {
        const r = await withKey((key) => explainLateAction(workspaceId, item.id, key));
        if (r.error) { toast.error(r.error); return; }
        setResult({ kind: "why-late", text: r.data?.explanation ?? "" });
      } else {
        const r = await withKey((key) => changeImpactAction(workspaceId, item.id, key));
        if (r.error) { toast.error(r.error); return; }
        setResult({ kind: "change-impact", text: r.data?.summary ?? "", affectedCount: r.data?.affected_item_ids.length ?? 0 });
      }
    });
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap gap-2">
        {item.doc_status === "approved" && (
          <Button className="text-ai" disabled={pending} size="sm" variant="outline" onClick={() => run("breakdown")}>
            <Sparkles aria-hidden className="mr-1.5 h-3.5 w-3.5" />
            Suggest task breakdown
          </Button>
        )}
        {item.due_at && (
          <Button className="text-ai" disabled={pending} size="sm" variant="outline" onClick={() => run("why-late")}>
            <Sparkles aria-hidden className="mr-1.5 h-3.5 w-3.5" />
            Why is this late?
          </Button>
        )}
        {item.doc_wiki_page_id && (
          <Button className="text-ai" disabled={pending} size="sm" variant="outline" onClick={() => run("change-impact")}>
            <Sparkles aria-hidden className="mr-1.5 h-3.5 w-3.5" />
            Change impact
          </Button>
        )}
      </div>

      {pending && <p className="text-sm text-muted-foreground">Thinking…</p>}

      {result?.kind === "breakdown" && (
        <div className="ai-surface flex flex-col gap-2">
          <p className="ai-badge w-fit">AI suggestion</p>
          {result.items.length === 0 && <p className="text-sm text-muted-foreground">No suggestions.</p>}
          {result.items.map((s, i) => (
            <div className="flex items-center justify-between gap-3 border-b border-border pb-2 last:border-0" key={i}>
              <div className="min-w-0">
                <p className="truncate text-sm font-medium">{s.title}</p>
                <p className="text-xs text-muted-foreground">{s.description}</p>
              </div>
              <CreateItemDialog
                allowedTypes={["task"]}
                defaultDescription={s.description}
                defaultParentId={item.id}
                defaultTitle={s.title}
                defaultType="task"
                tracks={tracks}
                triggerLabel="Create"
                workspaceId={workspaceId}
              />
            </div>
          ))}
        </div>
      )}

      {result?.kind === "why-late" && (
        <div className="ai-surface flex flex-col gap-1">
          <p className="ai-badge w-fit">AI suggestion</p>
          <p className="text-sm">{result.text}</p>
        </div>
      )}

      {result?.kind === "change-impact" && (
        <div className="ai-surface flex flex-col gap-1">
          <p className="ai-badge w-fit">AI suggestion</p>
          <p className="text-sm">{result.text}</p>
          <p className="text-xs text-muted-foreground">{result.affectedCount} related item(s) flagged.</p>
        </div>
      )}
    </div>
  );
}
