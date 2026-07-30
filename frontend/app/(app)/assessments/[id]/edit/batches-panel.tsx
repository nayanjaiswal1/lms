"use client";

import * as React from "react";
import { useQueryState } from "nuqs";
import { toast } from "sonner";
import { Users, Link, Copy } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { selectedBatchesParam } from "@/app/(app)/assessments/[id]/edit/selected-batches-param";
import { cn } from "@/lib/utils";
import type { Assessment, Batch } from "@/lib/assessments/types";

interface BatchesPanelProps {
  assessment: Assessment;
  batches: Batch[];
}

export function BatchesPanel({ assessment, batches }: BatchesPanelProps) {
  const [selected, setSelected] = useQueryState("selected", selectedBatchesParam);

  const toggleBatch = (id: string, on: boolean) =>
    setSelected(on ? [...selected, id] : selected.filter((b) => b !== id));

  return (
    <div className="flex flex-col gap-8">
      {assessment.parent_type === "hiring" && assessment.short_code && (
        <PublicLinkCard published={assessment.status !== "draft"} shortCode={assessment.short_code} />
      )}

      {batches.length === 0 ? (
        <p className="text-sm text-muted-foreground">Create a batch first to assign this assessment to a cohort.</p>
      ) : (
        <div className="grid-responsive-2">
          {batches.map((b) => {
            const isSelected = selected.includes(b.id);
            return (
              <Label
                className={cn(
                  "card-interactive relative flex cursor-pointer flex-col items-stretch gap-3 p-6 font-normal",
                  isSelected && "border-primary bg-primary/5 shadow-raised",
                )}
                key={b.id}
              >
                <Checkbox
                  checked={isSelected}
                  className="absolute right-4 top-4"
                  onCheckedChange={(c) => toggleBatch(b.id, Boolean(c))}
                />
                <span className="pr-8 text-base font-semibold leading-tight text-foreground">{b.name}</span>
                <p className="line-clamp-2 text-sm text-muted-foreground">
                  {b.description || "No description."}
                </p>
                <div className="mt-auto flex items-center justify-between border-t border-border pt-3 text-xs text-muted-foreground">
                  <span className="flex items-center gap-1.5">
                    <Users aria-hidden className="h-3.5 w-3.5" />
                    {b.member_count} member{b.member_count !== 1 ? "s" : ""}
                  </span>
                  <span className="capitalize">{b.status}</span>
                </div>
              </Label>
            );
          })}
        </div>
      )}
    </div>
  );
}

function PublicLinkCard({ shortCode, published }: { shortCode: string; published: boolean }) {
  const [open, setOpen] = React.useState(false);
  const base = process.env.NEXT_PUBLIC_APP_URL ?? "";
  const url = `${base}/hire/${shortCode}`;

  const copyLink = () => {
    void navigator.clipboard.writeText(url).then(() => toast.success("Link copied."));
  };

  if (!open) {
    return (
      <Button className="w-fit" variant="outline" onClick={() => setOpen(true)}>
        <Link aria-hidden className="h-4 w-4" /> Show candidate link
      </Button>
    );
  }

  return (
    <section className="flex flex-col gap-3">
      <button
        className="flex items-center gap-2 text-left"
        type="button"
        onClick={() => setOpen(false)}
      >
        <Link aria-hidden className="h-5 w-5 text-primary" />
        <h2 className="section-title">Public candidate link</h2>
      </button>
      <div className="card-base flex flex-col gap-4 p-6">
        {!published ? (
          <p className="text-sm text-muted-foreground">
            Publish this assessment to activate the public link. Candidates won&apos;t be able to access it until it&apos;s published.
          </p>
        ) : (
          <p className="text-sm text-muted-foreground">
            Share this link with candidates. They enter their name and email then take the test — no account required.
          </p>
        )}
        <div className="flex items-center gap-2 rounded-lg border border-border bg-muted px-3 py-2">
          <span className="flex-1 truncate font-mono text-sm text-foreground">{url}</span>
          <Button
            aria-label="Copy link"
            disabled={!published}
            size="icon"
            variant="ghost"
            onClick={copyLink}
          >
            <Copy aria-hidden className="h-4 w-4" />
          </Button>
        </div>
        {published && (
          <a
            className="text-sm font-medium text-primary hover:underline"
            href={url}
            rel="noopener noreferrer"
            target="_blank"
          >
            Open link →
          </a>
        )}
      </div>
    </section>
  );
}
