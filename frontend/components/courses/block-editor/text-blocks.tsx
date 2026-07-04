"use client";

import { Textarea } from "@/components/ui/textarea";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { cn } from "@/lib/utils";
import type { ParagraphBlock, HeadingBlock, CalloutBlock, DividerBlock, HeadingLevel, CalloutVariant } from "@/lib/courses/draft-types";

// ─── Paragraph ───────────────────────────────────────────────────────────────

interface ParagraphProps { block: ParagraphBlock; onChange: (b: ParagraphBlock) => void }

export function ParagraphBlockEditor({ block, onChange }: ParagraphProps) {
  return (
    <Textarea
      className="min-h-[80px] resize-none border-0 bg-transparent p-0 text-sm shadow-none focus-visible:ring-0 placeholder:text-muted-foreground/50"
      placeholder="Write something…"
      value={block.text}
      onChange={(e) => onChange({ ...block, text: e.target.value })}
    />
  );
}

// ─── Heading ─────────────────────────────────────────────────────────────────

interface HeadingProps { block: HeadingBlock; onChange: (b: HeadingBlock) => void }

export function HeadingBlockEditor({ block, onChange }: HeadingProps) {
  return (
    <div className="flex items-center gap-2">
      <Select
        value={block.level}
        onValueChange={(v) => onChange({ ...block, level: v as HeadingLevel })}
      >
        <SelectTrigger aria-label="Heading level" className="h-8 w-16 shrink-0 text-xs">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="h2">H2</SelectItem>
          <SelectItem value="h3">H3</SelectItem>
        </SelectContent>
      </Select>
      <Input
        className={cn(
          "border-0 bg-transparent p-0 shadow-none focus-visible:ring-0 font-semibold",
          block.level === "h2" ? "text-xl" : "text-lg",
        )}
        placeholder="Heading text…"
        value={block.text}
        onChange={(e) => onChange({ ...block, text: e.target.value })}
      />
    </div>
  );
}

// ─── Divider ─────────────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function DividerBlockEditor(_: { block: DividerBlock }) {
  return <hr className="border-border" />;
}

// ─── Callout ─────────────────────────────────────────────────────────────────

const CALLOUT_STYLES: Record<CalloutVariant, string> = {
  info:    "border-blue-500/40 bg-blue-500/10 text-blue-700 dark:text-blue-300",
  warning: "border-amber-500/40 bg-amber-500/10 text-amber-700 dark:text-amber-300",
  tip:     "border-green-500/40 bg-green-500/10 text-green-700 dark:text-green-300",
  danger:  "border-red-500/40 bg-red-500/10 text-red-700 dark:text-red-300",
};

const CALLOUT_LABELS: Record<CalloutVariant, string> = {
  info: "ℹ️ Info", warning: "⚠️ Warning", tip: "💡 Tip", danger: "🚨 Danger",
};

interface CalloutProps { block: CalloutBlock; onChange: (b: CalloutBlock) => void }

export function CalloutBlockEditor({ block, onChange }: CalloutProps) {
  return (
    <div className={cn("rounded-md border p-3 flex flex-col gap-2", CALLOUT_STYLES[block.variant])}>
      <Select
        value={block.variant}
        onValueChange={(v) => onChange({ ...block, variant: v as CalloutVariant })}
      >
        <SelectTrigger aria-label="Callout type" className="h-7 w-36 border-0 bg-transparent p-0 text-xs font-semibold shadow-none focus-visible:ring-0">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {(["info", "warning", "tip", "danger"] as CalloutVariant[]).map((v) => (
            <SelectItem key={v} value={v}>{CALLOUT_LABELS[v]}</SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Textarea
        className="min-h-[60px] resize-none border-0 bg-transparent p-0 text-sm shadow-none focus-visible:ring-0 placeholder:opacity-60"
        placeholder="Callout message…"
        value={block.text}
        onChange={(e) => onChange({ ...block, text: e.target.value })}
      />
    </div>
  );
}
