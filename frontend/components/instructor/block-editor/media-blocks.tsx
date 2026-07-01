"use client";

import { useState } from "react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Upload, Link as LinkIcon, Lock } from "lucide-react";
import { cn } from "@/lib/utils";
import { extractYouTubeId, youtubeEmbedUrl } from "@/components/instructor/block-editor/youtube-utils";
import type { ImageBlock, YouTubeBlock, VideoBlock } from "@/lib/courses/draft-types";

// ─── Shared: upload-or-url tabs ───────────────────────────────────────────────

interface AssetInputProps {
  url:        string;
  accept:     string;
  label:      string;
  onUrl:      (url: string) => void;
  onFile:     (file: File) => void;
}

function AssetInput({ url, accept, label, onUrl, onFile }: AssetInputProps) {
  const [tab, setTab] = useState<"upload" | "url">("url");
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
            {t === "url" ? "Paste URL" : "Upload file"}
          </button>
        ))}
      </div>
      {tab === "url" ? (
        <Input
          placeholder={`${label} URL…`}
          type="url"
          value={url}
          onChange={(e) => onUrl(e.target.value)}
        />
      ) : (
        <label className="flex cursor-pointer flex-col items-center gap-2 rounded-md border-2 border-dashed border-border px-4 py-6 text-center transition-colors hover:border-primary hover:bg-muted/40">
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

// ─── Image block ──────────────────────────────────────────────────────────────

interface ImageProps { block: ImageBlock; onChange: (b: ImageBlock) => void; onFile: (blockId: string, file: File) => void }

export function ImageBlockEditor({ block, onChange, onFile }: ImageProps) {
  const displayUrl = block.previewUrl ?? block.url;
  return (
    <div className="flex flex-col gap-3">
      <AssetInput
        url={block.url}
        accept="image/*"
        label="Image"
        onUrl={(url) => onChange({ ...block, url, previewUrl: undefined })}
        onFile={(file) => {
          onFile(block.id, file);
          onChange({ ...block, previewUrl: URL.createObjectURL(file), url: "" });
        }}
      />
      {displayUrl && (
        // eslint-disable-next-line @next/next/no-img-element
        <img alt={block.alt || "preview"} className="max-h-60 w-full rounded-md object-contain bg-muted" src={displayUrl} />
      )}
      <div className="grid grid-cols-2 gap-2">
        <div className="flex flex-col gap-1">
          <Label className="text-xs">Alt text</Label>
          <Input placeholder="Describe the image" value={block.alt} onChange={(e) => onChange({ ...block, alt: e.target.value })} />
        </div>
        <div className="flex flex-col gap-1">
          <Label className="text-xs">Caption</Label>
          <Input placeholder="Optional caption" value={block.caption} onChange={(e) => onChange({ ...block, caption: e.target.value })} />
        </div>
      </div>
    </div>
  );
}

// ─── YouTube block ────────────────────────────────────────────────────────────

interface YouTubeProps { block: YouTubeBlock; onChange: (b: YouTubeBlock) => void }

export function YouTubeBlockEditor({ block, onChange }: YouTubeProps) {
  const [raw, setRaw] = useState("");

  function handleInput(value: string) {
    setRaw(value);
    const id = extractYouTubeId(value);
    if (id) onChange({ ...block, videoId: id });
  }

  return (
    <div className="flex flex-col gap-3">
      <Input
        placeholder="Paste YouTube URL or video ID…"
        value={raw || (block.videoId ? `https://youtu.be/${block.videoId}` : "")}
        onChange={(e) => handleInput(e.target.value)}
      />
      {block.videoId ? (
        <div className="flex flex-col gap-2">
          <div className="aspect-video w-full overflow-hidden rounded-md bg-muted">
            <iframe
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowFullScreen
              className="h-full w-full"
              src={youtubeEmbedUrl(block.videoId)}
              title="YouTube preview"
            />
          </div>
          <Input
            placeholder="Optional caption"
            value={block.caption}
            onChange={(e) => onChange({ ...block, caption: e.target.value })}
          />
        </div>
      ) : (
        <p className="text-xs text-muted-foreground">
          Supports: youtube.com/watch, youtu.be, youtube.com/shorts
        </p>
      )}
    </div>
  );
}

// ─── Uploaded video block ─────────────────────────────────────────────────────

interface VideoProps { block: VideoBlock; onChange: (b: VideoBlock) => void; onFile: (blockId: string, file: File) => void }

export function VideoBlockEditor({ block, onChange, onFile }: VideoProps) {
  const displayUrl = block.previewUrl ?? block.url;
  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2 rounded-md border border-border bg-muted/50 px-3 py-2 text-xs text-muted-foreground">
        <Lock className="h-3.5 w-3.5 shrink-0" />
        Enrolled students only · served via signed URL (link expires after 15 min)
      </div>
      <Input
        placeholder="Video title"
        value={block.title}
        onChange={(e) => onChange({ ...block, title: e.target.value })}
      />
      <AssetInput
        url={block.url}
        accept="video/*"
        label="Video"
        onUrl={(url) => onChange({ ...block, url, storageKey: "", previewUrl: undefined })}
        onFile={(file) => {
          onFile(block.id, file);
          onChange({ ...block, previewUrl: URL.createObjectURL(file), url: "", storageKey: "" });
        }}
      />
      {displayUrl && (
        <video
          className="max-h-60 w-full rounded-md bg-muted"
          controls
          src={displayUrl}
        />
      )}
    </div>
  );
}

// ─── Re-export for convenience ────────────────────────────────────────────────

export { Button };
