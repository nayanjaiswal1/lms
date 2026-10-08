import { z } from "zod";
import { HINT_LEVELS, TEXT_BLOCK_KINDS } from "@/lib/labs/builder/options";
import type { BlockManifest, TextBlockKind, TextBlockManifest } from "@/lib/labs/builder/types";

// Form <-> manifest mapping for org text blocks (labauthor prepareTextManifest).
// Every list is edited as one block of text, one entry per line.

/** Mirrors labauthor maxTemplateLen / maxLadderItem. */
const MAX_TEMPLATE = 20000;
const MAX_LADDER_ITEM = 2000;

const TextBlockBase = z.object({
  title: z.string().trim().min(1, "Give the block a title").max(200),
  summary: z.string().trim().min(1, "Add a one-line summary").max(1000),
  changelog: z.string().trim().max(1000),
  templateMd: z.string().max(MAX_TEMPLATE),
  severity: z.string(),
  persona: z.string().trim().max(60),
  redHerrings: z.string(),
  hints: z.array(z.string().max(MAX_LADDER_ITEM)).length(HINT_LEVELS),
  keyPoints: z.string(),
  misconceptions: z.string(),
  presetTarget: z.string().trim(),
  presetValues: z.string(),
});
export type TextBlockValues = z.infer<typeof TextBlockBase>;

function splitLines(text: string): string[] {
  return text.split("\n").map((l) => l.trim()).filter(Boolean);
}

function parseValues(raw: string): Record<string, unknown> | null {
  try {
    const v: unknown = JSON.parse(raw);
    return typeof v === "object" && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

/** The schema for one kind: the shared fields plus that kind's required content. */
export function textBlockSchema(kind: TextBlockKind) {
  return TextBlockBase.superRefine((v, ctx) => {
    const need = (ok: boolean, path: string, message: string) => {
      if (!ok) ctx.addIssue({ code: "custom", path: [path], message });
    };
    switch (kind) {
      case "ticket":
        need(v.templateMd.trim() !== "", "templateMd", "Write the ticket");
        break;
      case "hints":
        v.hints.forEach((h, i) => need(h.trim() !== "", `hints.${i}`, "Every level needs a hint"));
        break;
      case "rubric":
        need(splitLines(v.keyPoints).length > 0, "keyPoints", "List at least one key point");
        break;
      case "preset":
        need(v.presetTarget !== "", "presetTarget", "Name the block this preset applies to");
        need(Object.keys(parseValues(v.presetValues) ?? {}).length > 0, "presetValues", "Enter a JSON object with at least one value");
        break;
    }
  });
}

export function emptyValues(): TextBlockValues {
  return {
    title: "", summary: "", changelog: "", templateMd: "", severity: "", persona: "", redHerrings: "",
    hints: Array.from({ length: HINT_LEVELS }, () => ""), keyPoints: "", misconceptions: "",
    presetTarget: "", presetValues: "",
  };
}

export function toValues(m: BlockManifest): TextBlockValues {
  const base = emptyValues();
  return {
    ...base,
    title: m.title,
    summary: m.summary,
    templateMd: m.ticket?.template_md ?? "",
    severity: m.ticket?.severity ?? "",
    persona: m.ticket?.persona ?? "",
    redHerrings: (m.ticket?.red_herrings ?? []).join("\n"),
    hints: m.hints?.ladder ?? base.hints,
    keyPoints: (m.rubric?.key_points ?? []).join("\n"),
    misconceptions: (m.rubric?.misconceptions ?? []).join("\n"),
    presetTarget: m.preset?.target ?? "",
    presetValues: m.preset ? JSON.stringify(m.preset.values, null, 2) : "",
  };
}

export function toManifest(kind: TextBlockKind, v: TextBlockValues): TextBlockManifest {
  const base = { kind, title: v.title, summary: v.summary, changelog: v.changelog || undefined };
  switch (kind) {
    case "ticket":
      return {
        ...base,
        ticket: {
          template_md: v.templateMd,
          severity: v.severity || undefined,
          persona: v.persona || undefined,
          red_herrings: splitLines(v.redHerrings),
        },
      };
    case "hints":
      return { ...base, hints: { ladder: v.hints.map((h) => h.trim()) } };
    case "rubric":
      return { ...base, rubric: { key_points: splitLines(v.keyPoints), misconceptions: splitLines(v.misconceptions) } };
    case "preset":
      return { ...base, preset: { target: v.presetTarget, values: parseValues(v.presetValues) ?? {} } };
  }
}

export function isTextKind(kind: string | undefined): kind is TextBlockKind {
  return TEXT_BLOCK_KINDS.some((k) => k.kind === kind);
}
