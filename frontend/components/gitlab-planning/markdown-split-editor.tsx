"use client";

import { useRef, useState } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { ArrowLeftRight, Bold, Code, Columns2, Heading, Italic, Link2, ListChecks, RefreshCw, Table } from "lucide-react";
import { cn } from "@/lib/utils";

type Mode = "write" | "split" | "preview";

const MODES: { key: Mode; label: string }[] = [
  { key: "write", label: "Write" },
  { key: "split", label: "Split View" },
  { key: "preview", label: "Preview" },
];

// [label, icon, before, after] — wraps the current selection.
const FORMATS = [
  ["Bold (**text**)", Bold, "**", "**"],
  ["Italic (*text*)", Italic, "*", "*"],
  ["Heading", Heading, "### ", ""],
  ["Code Block", Code, "```\n", "\n```"],
  ["Task List", ListChecks, "- [ ] ", ""],
  ["Insert Link", Link2, "[", "](https://)"],
  ["Table", Table, "| Column | Column |\n| --- | --- |\n| ", " |  |"],
] as const;

interface MarkdownSplitEditorProps {
  initialValue: string;
}

export function MarkdownSplitEditor({ initialValue }: MarkdownSplitEditorProps) {
  const [md, setMd] = useState(initialValue);
  const [ui, setUi] = useState<{ mode: Mode; sync: boolean }>({ mode: "split", sync: true });
  const source = useRef<HTMLTextAreaElement>(null);
  const preview = useRef<HTMLDivElement>(null);
  // The pane we just scrolled programmatically — its echo scroll event is ignored.
  const echo = useRef<HTMLElement | null>(null);

  function mirror(from: HTMLElement | null, to: HTMLElement | null) {
    if (!ui.sync || ui.mode !== "split" || !from || !to) return;
    if (echo.current === from) {
      echo.current = null;
      return;
    }
    const ratio = from.scrollTop / Math.max(1, from.scrollHeight - from.clientHeight);
    const target = Math.round(ratio * (to.scrollHeight - to.clientHeight));
    if (Math.abs(to.scrollTop - target) < 1) return;
    echo.current = to;
    to.scrollTop = target;
  }

  function format(before: string, after: string) {
    const el = source.current;
    if (!el) return;
    const { selectionStart: s, selectionEnd: e } = el;
    setMd(md.slice(0, s) + before + md.slice(s, e) + after + md.slice(e));
    el.focus();
  }

  return (
    <section aria-label="Description" className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold uppercase tracking-tight text-(--m-on-surface)">Description</span>
          <span className="m-label-sm rounded bg-(--m-primary-fixed) px-2 py-0.5 text-[10px] text-(--m-on-primary-fixed)">Markdown Editor</span>
        </div>
        <div aria-label="Editor mode" className="flex items-center rounded-lg bg-(--m-sc-low) p-0.5" role="tablist">
          {MODES.map(({ key, label }) => (
            <button
              aria-selected={ui.mode === key}
              className={cn(
                "m-label-sm flex items-center gap-1 rounded px-2 py-1 text-[11px] transition-colors",
                ui.mode === key ? "bg-(--m-sc-lowest) text-(--m-primary) shadow-2xs" : "text-(--m-on-surface-variant) hover:text-(--m-on-surface)",
                key === "split" && "hidden md:flex",
              )}
              key={key}
              role="tab"
              type="button"
              onClick={() => setUi({ ...ui, mode: key })}
            >
              {key === "split" && <Columns2 aria-hidden className="size-3.5" />}
              <span>{label}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="flex flex-col overflow-hidden rounded-xl border border-(--m-outline-variant)/40 bg-(--m-sc-lowest) shadow-2xs">
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-(--m-outline-variant)/30 bg-(--m-sc-low) px-3 py-1.5">
          <div className="flex items-center gap-1 text-(--m-on-surface-variant)">
            {FORMATS.map(([label, Icon, before, after], i) => (
              <span className="flex items-center" key={label}>
                {i === 3 && <span className="mx-0.5 h-3.5 w-px bg-(--m-outline-variant)/40" />}
                <button aria-label={label} className="rounded p-1 hover:bg-(--m-sc) hover:text-(--m-on-surface)" title={label} type="button" onClick={() => format(before, after)}>
                  <Icon aria-hidden className="size-3.5" />
                </button>
              </span>
            ))}
          </div>
          <div className="flex items-center gap-2">
            <span className="m-label-sm mr-1 hidden items-center gap-1 text-[10px] text-(--m-on-surface-variant) sm:flex">
              <RefreshCw aria-hidden className="size-3 text-(--m-tertiary)" />
              {ui.sync ? "1:1 Bi-directional" : "Independent scroll"}
            </span>
            <button
              aria-pressed={ui.sync}
              className="group m-label-sm flex select-none items-center gap-1.5 rounded-lg border border-(--mc)/20 bg-(--m-sc) px-2 py-1 shadow-2xs transition-all hover:bg-(--m-sc-high)"
              data-mtone={ui.sync ? "tertiary" : "muted"}
              title="Toggle bi-directional scroll synchronization between editor and preview"
              type="button"
              onClick={() => setUi({ ...ui, sync: !ui.sync })}
            >
              <span className="relative flex size-2">
                {ui.sync && <span className="absolute inline-flex size-full animate-ping rounded-full bg-(--mc) opacity-75" />}
                <span className="relative inline-flex size-2 rounded-full bg-(--mc)" />
              </span>
              <span className="text-[11px] font-medium text-(--mc)">Sync Scroll: {ui.sync ? "ON" : "OFF"}</span>
              <ArrowLeftRight aria-hidden className="ml-0.5 size-3.5 text-(--mc) transition-transform duration-300 group-hover:rotate-180" />
            </button>
          </div>
        </div>

        <div className={cn("grid h-96 grid-cols-1 divide-y divide-(--m-outline-variant)/30 md:divide-x md:divide-y-0", ui.mode === "split" && "md:grid-cols-2")}>
          <div className={cn("flex h-full min-h-0 flex-col bg-(--m-sc-lowest)/70", ui.mode === "preview" && "hidden", ui.mode === "split" && "max-md:hidden")}>
            <div className="m-label-sm flex select-none items-center justify-between border-b border-(--m-outline-variant)/20 bg-(--m-sc-low)/70 px-3 py-1 text-[10px] text-(--m-on-surface-variant)">
              <span>MARKDOWN SOURCE</span>
              <span className="text-(--m-outline)">UTF-8 • ln {md.split("\n").length}</span>
            </div>
            <textarea
              aria-label="Markdown source"
              className="ae-mono min-h-0 w-full flex-1 resize-none border-0 bg-transparent p-3 text-[11.5px] leading-relaxed text-(--m-on-surface) selection:bg-(--m-primary-fixed) focus:outline-none"
              ref={source}
              spellCheck={false}
              value={md}
              onChange={(e) => setMd(e.target.value)}
              onScroll={() => mirror(source.current, preview.current)}
            />
          </div>
          <div className={cn("flex h-full min-h-0 flex-col", ui.mode === "write" && "hidden")}>
            <div className="m-label-sm flex select-none items-center justify-between border-b border-(--m-outline-variant)/20 bg-(--m-sc-low)/70 px-3 py-1 text-[10px] text-(--m-on-surface-variant)">
              <span>LIVE PREVIEW</span>
              <span className="text-(--m-outline)">GitLab Flavored</span>
            </div>
            <div className="ae-md min-h-0 flex-1 overflow-y-auto p-3" ref={preview} onScroll={() => mirror(preview.current, source.current)}>
              <ReactMarkdown remarkPlugins={[remarkGfm]}>{md}</ReactMarkdown>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
