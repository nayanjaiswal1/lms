"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  ChevronUp, ChevronDown, Trash2, Plus,
  Type, Heading, Image, Code2, Tv, Video, FileText, FileDown, Minus, AlertCircle,
} from "lucide-react";
import { cn } from "@/lib/utils";
import type { ContentBlock } from "@/lib/courses/draft-types";
import { ParagraphBlockEditor }  from "@/components/instructor/block-editor/text-blocks";
import { HeadingBlockEditor }    from "@/components/instructor/block-editor/text-blocks";
import { DividerBlockEditor }    from "@/components/instructor/block-editor/text-blocks";
import { CalloutBlockEditor }    from "@/components/instructor/block-editor/text-blocks";
import { ImageBlockEditor }      from "@/components/instructor/block-editor/media-blocks";
import { YouTubeBlockEditor }    from "@/components/instructor/block-editor/media-blocks";
import { VideoBlockEditor }      from "@/components/instructor/block-editor/media-blocks";
import { PdfBlockEditor }        from "@/components/instructor/block-editor/file-blocks";
import { DownloadBlockEditor }   from "@/components/instructor/block-editor/file-blocks";
import { CodeBlockEditor }       from "@/components/instructor/block-editor/file-blocks";

// ─── Block picker ─────────────────────────────────────────────────────────────

const BLOCK_MENU: { type: ContentBlock["type"]; icon: React.ComponentType<{ className?: string }>; label: string }[] = [
  { type: "paragraph", icon: Type,        label: "Text"       },
  { type: "heading",   icon: Heading,     label: "Heading"    },
  { type: "image",     icon: Image,       label: "Image"      },
  { type: "code",      icon: Code2,       label: "Code"       },
  { type: "youtube",   icon: Tv,          label: "YouTube"    },
  { type: "video",     icon: Video,       label: "Video"      },
  { type: "pdf",       icon: FileText,    label: "PDF"        },
  { type: "download",  icon: FileDown,    label: "Download"   },
  { type: "callout",   icon: AlertCircle, label: "Callout"    },
  { type: "divider",   icon: Minus,       label: "Divider"    },
];

interface BlockPickerProps { onPick: (type: ContentBlock["type"]) => void; onClose: () => void }

function BlockPicker({ onPick, onClose }: BlockPickerProps) {
  return (
    <div className="rounded-md border border-border bg-card shadow-raised p-2 grid grid-cols-5 gap-1">
      {BLOCK_MENU.map(({ type, icon: Icon, label }) => (
        <button
          key={type}
          type="button"
          onClick={() => { onPick(type); onClose(); }}
          className="flex flex-col items-center gap-1 rounded p-2 text-center hover:bg-muted transition-colors"
        >
          <Icon className="h-4 w-4 text-muted-foreground" />
          <span className="text-[10px] text-muted-foreground">{label}</span>
        </button>
      ))}
    </div>
  );
}

// ─── Block renderer ───────────────────────────────────────────────────────────

interface BlockItemProps {
  block:    ContentBlock;
  index:    number;
  total:    number;
  onChange: (b: ContentBlock) => void;
  onMove:   (dir: "up" | "down") => void;
  onRemove: () => void;
  onFile:   (blockId: string, file: File) => void;
}

function BlockItem({ block, index, total, onChange, onMove, onRemove, onFile }: BlockItemProps) {
  const label = BLOCK_MENU.find((m) => m.type === block.type)?.label ?? block.type;

  return (
    <div className="group relative flex gap-2">
      {/* Controls */}
      <div className="flex shrink-0 flex-col items-center gap-0.5 pt-1 opacity-0 transition-opacity group-hover:opacity-100">
        <button type="button" aria-label="Move up" disabled={index === 0} onClick={() => onMove("up")}
          className="rounded p-0.5 text-muted-foreground hover:text-foreground disabled:opacity-30">
          <ChevronUp className="h-3.5 w-3.5" />
        </button>
        <button type="button" aria-label="Move down" disabled={index === total - 1} onClick={() => onMove("down")}
          className="rounded p-0.5 text-muted-foreground hover:text-foreground disabled:opacity-30">
          <ChevronDown className="h-3.5 w-3.5" />
        </button>
        <button type="button" aria-label={`Remove ${label} block`} onClick={onRemove}
          className="rounded p-0.5 text-muted-foreground hover:text-destructive">
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>

      {/* Block content */}
      <div className="flex-1 min-w-0">
        {block.type === "paragraph" && <ParagraphBlockEditor block={block} onChange={onChange} />}
        {block.type === "heading"   && <HeadingBlockEditor   block={block} onChange={onChange} />}
        {block.type === "divider"   && <DividerBlockEditor   block={block} />}
        {block.type === "callout"   && <CalloutBlockEditor   block={block} onChange={onChange} />}
        {block.type === "image"     && <ImageBlockEditor     block={block} onChange={onChange} onFile={onFile} />}
        {block.type === "youtube"   && <YouTubeBlockEditor   block={block} onChange={onChange} />}
        {block.type === "video"     && <VideoBlockEditor     block={block} onChange={onChange} onFile={onFile} />}
        {block.type === "pdf"       && <PdfBlockEditor       block={block} onChange={onChange} onFile={onFile} />}
        {block.type === "download"  && <DownloadBlockEditor  block={block} onChange={onChange} onFile={onFile} />}
        {block.type === "code"      && <CodeBlockEditor      block={block} onChange={onChange} />}
      </div>
    </div>
  );
}

// ─── Main editor ──────────────────────────────────────────────────────────────

interface BlockEditorProps {
  blocks:   ContentBlock[];
  onChange: (blocks: ContentBlock[]) => void;
  onFile:   (blockId: string, file: File) => void;
}

export function BlockEditor({ blocks, onChange, onFile }: BlockEditorProps) {
  const [pickerOpen, setPickerOpen] = useState(false);

  function updateBlock(index: number, updated: ContentBlock) {
    const next = [...blocks];
    next[index] = updated;
    onChange(next);
  }

  function removeBlock(index: number) {
    onChange(blocks.filter((_, i) => i !== index));
  }

  function moveBlock(index: number, dir: "up" | "down") {
    const next = [...blocks];
    const target = dir === "up" ? index - 1 : index + 1;
    if (target < 0 || target >= next.length) return;
    [next[index], next[target]] = [next[target], next[index]];
    onChange(next);
  }

  function addBlock(type: ContentBlock["type"]) {
    // Import dynamically to avoid circular dep issue — type comes from draft-types
    import("@/lib/courses/draft-types").then(({ makeBlock }) => {
      onChange([...blocks, makeBlock(type)]);
    });
  }

  return (
    <div className="flex flex-col gap-4">
      {blocks.length === 0 && (
        <p className="text-sm text-muted-foreground text-center py-8">
          No content yet. Click <strong>Add block</strong> below to start building.
        </p>
      )}

      {blocks.map((block, index) => (
        <BlockItem
          key={block.id}
          block={block}
          index={index}
          total={blocks.length}
          onChange={(b) => updateBlock(index, b)}
          onMove={(dir) => moveBlock(index, dir)}
          onRemove={() => removeBlock(index)}
          onFile={onFile}
        />
      ))}

      <div className={cn("relative", blocks.length > 0 && "mt-2")}>
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="w-full border-dashed text-muted-foreground hover:text-foreground"
          onClick={() => setPickerOpen((v) => !v)}
        >
          <Plus className="mr-1.5 h-3.5 w-3.5" />
          Add block
        </Button>
        {pickerOpen && (
          <div className="absolute bottom-full left-0 right-0 z-dropdown mb-2">
            <BlockPicker onPick={addBlock} onClose={() => setPickerOpen(false)} />
          </div>
        )}
      </div>
    </div>
  );
}
