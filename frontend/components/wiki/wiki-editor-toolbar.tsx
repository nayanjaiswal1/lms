"use client";

import { useState } from "react";
import type { Editor } from "@tiptap/react";
import {
  Bold, Italic, Underline as UnderlineIcon, Strikethrough, Code, Heading1, Heading2, Heading3,
  List, ListOrdered, ListChecks, Quote, TableIcon, ImageIcon, LinkIcon, Minus, Undo2, Redo2,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import { cn } from "@/lib/utils";
import { apiFetch } from "@/lib/client/api";
import { uploadWikiImageAction } from "@/lib/wiki/actions";
import type { WikiPageDetail, WikiSearchResult } from "@/lib/server/wiki";
import ROUTES from "@/lib/routes";
import { toast } from "sonner";

interface WikiEditorToolbarProps {
  editor: Editor;
}

function ToolbarButton({ active, onClick, label, children }: { active?: boolean; onClick: () => void; label: string; children: React.ReactNode }) {
  return (
    <Button
      aria-label={label}
      className={cn("touch-target h-8 w-8 p-0", active && "bg-muted text-primary")}
      title={label}
      type="button"
      variant="ghost"
      onClick={onClick}
    >
      {children}
    </Button>
  );
}

export function WikiEditorToolbar({ editor }: WikiEditorToolbarProps) {
  const [linkQuery, setLinkQuery] = useState("");
  const [linkResults, setLinkResults] = useState<WikiSearchResult[]>([]);

  async function handleImageUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadWikiImageAction(fd);
    if (!res.ok || !res.data) {
      toast.error(res.error ?? "Image upload failed.");
      return;
    }
    editor.chain().focus().setImage({ src: res.data.url }).run();
  }

  async function runLinkSearch(query: string) {
    setLinkQuery(query);
    if (query.trim().length < 2) {
      setLinkResults([]);
      return;
    }
    const results = await apiFetch<WikiSearchResult[]>(`/wiki/search?q=${encodeURIComponent(query)}`);
    setLinkResults(results ?? []);
  }

  async function insertPageLink(result: WikiSearchResult) {
    const detail = await apiFetch<WikiPageDetail>(`/wiki/pages/${result.page_id}`);
    if (!detail) {
      toast.error("Couldn't load that page.");
      return;
    }
    const path = detail.breadcrumb.map((b) => b.slug);
    const href = ROUTES.wikiPage(detail.space_slug, ...path);
    const { from, to } = editor.state.selection;
    if (from === to) {
      editor.chain().focus().insertContent({ type: "text", text: result.title, marks: [{ type: "link", attrs: { href } }] }).run();
    } else {
      editor.chain().focus().setLink({ href }).run();
    }
    setLinkQuery("");
    setLinkResults([]);
  }

  return (
    <div className="flex flex-wrap items-center gap-0.5 border-b border-border p-2">
      <ToolbarButton active={editor.isActive("bold")} label="Bold" onClick={() => editor.chain().focus().toggleBold().run()}>
        <Bold aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton active={editor.isActive("italic")} label="Italic" onClick={() => editor.chain().focus().toggleItalic().run()}>
        <Italic aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton active={editor.isActive("underline")} label="Underline" onClick={() => editor.chain().focus().toggleUnderline().run()}>
        <UnderlineIcon aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton active={editor.isActive("strike")} label="Strikethrough" onClick={() => editor.chain().focus().toggleStrike().run()}>
        <Strikethrough aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton active={editor.isActive("code")} label="Inline code" onClick={() => editor.chain().focus().toggleCode().run()}>
        <Code aria-hidden className="h-4 w-4" />
      </ToolbarButton>

      <Separator className="mx-1 h-6" orientation="vertical" />

      <ToolbarButton active={editor.isActive("heading", { level: 1 })} label="Heading 1" onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}>
        <Heading1 aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton active={editor.isActive("heading", { level: 2 })} label="Heading 2" onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}>
        <Heading2 aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton active={editor.isActive("heading", { level: 3 })} label="Heading 3" onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}>
        <Heading3 aria-hidden className="h-4 w-4" />
      </ToolbarButton>

      <Separator className="mx-1 h-6" orientation="vertical" />

      <ToolbarButton active={editor.isActive("bulletList")} label="Bullet list" onClick={() => editor.chain().focus().toggleBulletList().run()}>
        <List aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton active={editor.isActive("orderedList")} label="Numbered list" onClick={() => editor.chain().focus().toggleOrderedList().run()}>
        <ListOrdered aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton active={editor.isActive("taskList")} label="Checklist" onClick={() => editor.chain().focus().toggleTaskList().run()}>
        <ListChecks aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton active={editor.isActive("blockquote")} label="Quote" onClick={() => editor.chain().focus().toggleBlockquote().run()}>
        <Quote aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton active={editor.isActive("codeBlock")} label="Code block" onClick={() => editor.chain().focus().toggleCodeBlock().run()}>
        <span aria-hidden className="text-xs font-mono">{"{ }"}</span>
      </ToolbarButton>

      <Separator className="mx-1 h-6" orientation="vertical" />

      <ToolbarButton label="Insert table" onClick={() => editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()}>
        <TableIcon aria-hidden className="h-4 w-4" />
      </ToolbarButton>

      <label className="touch-target flex h-8 w-8 cursor-pointer items-center justify-center rounded-md text-foreground hover:bg-muted" title="Insert image">
        <ImageIcon aria-hidden className="h-4 w-4" />
        <input accept="image/*" className="sr-only" type="file" onChange={handleImageUpload} />
      </label>

      <Popover
        onOpenChange={(open) => {
          if (!open) {
            setLinkQuery("");
            setLinkResults([]);
          }
        }}
      >

        <PopoverTrigger asChild>
          <span>
            <ToolbarButton active={editor.isActive("link")} label="Link to another page" onClick={() => {}}>
              <LinkIcon aria-hidden className="h-4 w-4" />
            </ToolbarButton>
          </span>
        </PopoverTrigger>
        <PopoverContent align="start" className="w-72 p-2">
          <Input
            autoFocus
            placeholder="Search pages…"
            value={linkQuery}
            onChange={(e) => void runLinkSearch(e.target.value)}
          />
          {linkResults.length > 0 && (
            <ul className="mt-2 max-h-56 space-y-0.5 overflow-y-auto">
              {linkResults.map((r) => (
                <li key={r.page_id}>
                  <button
                    className="w-full rounded-md px-2 py-1.5 text-left text-sm hover:bg-muted"
                    type="button"
                    onClick={() => void insertPageLink(r)}
                  >
                    <span className="block truncate font-medium">{r.title}</span>
                    <span className="block truncate text-xs text-muted-foreground">{r.space_name}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </PopoverContent>
      </Popover>

      <ToolbarButton label="Divider" onClick={() => editor.chain().focus().setHorizontalRule().run()}>
        <Minus aria-hidden className="h-4 w-4" />
      </ToolbarButton>

      <Separator className="mx-1 h-6" orientation="vertical" />

      <ToolbarButton label="Undo" onClick={() => editor.chain().focus().undo().run()}>
        <Undo2 aria-hidden className="h-4 w-4" />
      </ToolbarButton>
      <ToolbarButton label="Redo" onClick={() => editor.chain().focus().redo().run()}>
        <Redo2 aria-hidden className="h-4 w-4" />
      </ToolbarButton>
    </div>
  );
}
