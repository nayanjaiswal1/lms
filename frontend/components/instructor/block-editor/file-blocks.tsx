"use client";

import { useState } from "react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Upload, Link as LinkIcon, FileDown } from "lucide-react";
import { cn } from "@/lib/utils";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { CodeEditor } from "@/components/shared/code-editor";
import { CODE_LANGUAGE_OPTIONS } from "@/lib/constants";
import type { PdfBlock, DownloadBlock, CodeBlock } from "@/lib/courses/draft-types";

// ─── Shared: upload-or-url input ─────────────────────────────────────────────

interface AssetInputProps {
  url:    string;
  accept: string;
  label:  string;
  onUrl:  (url: string) => void;
  onFile: (file: File) => void;
}

function AssetInput({ url, accept, label, onUrl, onFile }: AssetInputProps) {
  const [tab, setTab] = useState<"url" | "upload">("url");
  return (
    <div className="flex flex-col gap-2">
      <div className="flex gap-1 text-xs">
        {(["url", "upload"] as const).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTab(t)}
            className={cn(
              "flex items-center gap-1 rounded px-2 py-1 transition-colors",
              tab === t ? "bg-muted font-medium" : "text-muted-foreground hover:text-foreground",
            )}
          >
            {t === "url" ? <LinkIcon className="h-3 w-3" /> : <Upload className="h-3 w-3" />}
            {t === "url" ? "Paste URL" : "Upload"}
          </button>
        ))}
      </div>
      {tab === "url" ? (
        <Input placeholder={`${label} URL…`} type="url" value={url} onChange={(e) => onUrl(e.target.value)} />
      ) : (
        <label className="flex cursor-pointer flex-col items-center gap-2 rounded-md border-2 border-dashed border-border px-4 py-5 text-center hover:border-primary hover:bg-muted/40 transition-colors">
          <Upload className="h-5 w-5 text-muted-foreground" />
          <span className="text-xs text-muted-foreground">Click to choose a file</span>
          <input
            accept={accept}
            className="sr-only"
            type="file"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) onFile(f);
            }}
          />
        </label>
      )}
    </div>
  );
}

// ─── PDF block ────────────────────────────────────────────────────────────────

interface PdfProps { block: PdfBlock; onChange: (b: PdfBlock) => void; onFile: (blockId: string, file: File) => void }

export function PdfBlockEditor({ block, onChange, onFile }: PdfProps) {
  const displayUrl = block.previewUrl ?? block.url;
  return (
    <div className="flex flex-col gap-3">
      <Input
        placeholder="Display title (optional)"
        value={block.title}
        onChange={(e) => onChange({ ...block, title: e.target.value })}
      />
      <AssetInput
        url={block.url}
        accept=".pdf,application/pdf"
        label="PDF"
        onUrl={(url) => onChange({ ...block, url, previewUrl: undefined })}
        onFile={(file) => {
          onFile(block.id, file);
          onChange({ ...block, previewUrl: URL.createObjectURL(file), url: "" });
        }}
      />
      {displayUrl && (
        <div className="flex flex-col gap-1">
          <Label className="text-xs text-muted-foreground">Preview</Label>
          <iframe className="h-64 w-full rounded-md border border-border" src={displayUrl} title="PDF preview" />
        </div>
      )}
    </div>
  );
}

// ─── Download block ───────────────────────────────────────────────────────────

interface DownloadProps { block: DownloadBlock; onChange: (b: DownloadBlock) => void; onFile: (blockId: string, file: File) => void }

export function DownloadBlockEditor({ block, onChange, onFile }: DownloadProps) {
  const hasAsset = !!(block.previewUrl ?? block.url);
  return (
    <div className="flex flex-col gap-3">
      <div className="grid grid-cols-2 gap-2">
        <div className="flex flex-col gap-1">
          <Label className="text-xs">File name / label</Label>
          <Input placeholder="e.g. starter-code.zip" value={block.filename} onChange={(e) => onChange({ ...block, filename: e.target.value })} />
        </div>
        <div className="flex flex-col gap-1">
          <Label className="text-xs">Description</Label>
          <Input placeholder="Optional description" value={block.description} onChange={(e) => onChange({ ...block, description: e.target.value })} />
        </div>
      </div>
      <AssetInput
        url={block.url}
        accept="*"
        label="File"
        onUrl={(url) => onChange({ ...block, url, previewUrl: undefined })}
        onFile={(file) => {
          onFile(block.id, file);
          onChange({ ...block, previewUrl: URL.createObjectURL(file), url: "", filename: block.filename || file.name });
        }}
      />
      {hasAsset && (
        <div className="flex items-center gap-2 rounded-md border border-border bg-muted/50 px-3 py-2 text-sm">
          <FileDown className="h-4 w-4 shrink-0 text-primary" />
          <span className="truncate font-medium">{block.filename || "Download"}</span>
          {block.description && <span className="text-xs text-muted-foreground">— {block.description}</span>}
        </div>
      )}
    </div>
  );
}

// ─── Code block ───────────────────────────────────────────────────────────────

interface CodeProps { block: CodeBlock; onChange: (b: CodeBlock) => void }

export function CodeBlockEditor({ block, onChange }: CodeProps) {
  return (
    <div className="flex flex-col gap-2">
      <Select
        value={block.language}
        onValueChange={(v) => onChange({ ...block, language: v })}
      >
        <SelectTrigger aria-label="Programming language" className="h-8 w-36 text-xs">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {CODE_LANGUAGE_OPTIONS.map((o) => (
            <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
          ))}
        </SelectContent>
      </Select>
      <CodeEditor
        height="240px"
        language={block.language}
        value={block.code}
        onChange={(v) => onChange({ ...block, code: v ?? "" })}
      />
    </div>
  );
}
