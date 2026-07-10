"use client";

import { useState } from "react";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Upload, Link as LinkIcon, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { COURSE_DIFFICULTY_OPTIONS } from "@/lib/constants";
import type { CourseInfo } from "@/lib/courses/draft-types";
import { useCoverCompression } from "@/lib/courses/use-cover-compression";
import { CoverCompressionPreview } from "@/components/courses/wizard/cover-compression-preview";

interface InfoTabProps {
  info:          CourseInfo;
  coverFile:     File | null;
  onChange:      (info: Partial<CourseInfo>) => void;
  onCoverFile:   (file: File | null) => void;
}

// ─── Info tab ───────────────────────────────────────────────────────────────

export function InfoTab({ info, coverFile, onChange, onCoverFile }: InfoTabProps) {
  const [coverTab, setCoverTab] = useState<"url" | "upload">("upload");
  const [tagInput, setTagInput] = useState("");
  const compression = useCoverCompression();

  const coverPreview = coverFile ? URL.createObjectURL(coverFile) : info.cover_url || null;

  function applyCompressedCover(blob: Blob, fileName: string) {
    onCoverFile(new File([blob], fileName, { type: blob.type }));
    onChange({ cover_url: "" });
    compression.clear();
  }

  function keepOriginalCover(file: File) {
    onCoverFile(file);
    onChange({ cover_url: "" });
    compression.clear();
  }

  function renderCompressionPreview() {
    const { originalFile, compressedBlob, originalPreviewUrl, compressedPreviewUrl, compressedSize, width, height } = compression;
    if (!originalFile || !compressedBlob || !originalPreviewUrl || !compressedPreviewUrl) return null;
    return (
      <CoverCompressionPreview
        compressedPreviewUrl={compressedPreviewUrl}
        compressedSize={compressedSize}
        height={height}
        originalPreviewUrl={originalPreviewUrl}
        originalSize={originalFile.size}
        width={width}
        onKeepOriginal={() => keepOriginalCover(originalFile)}
        onUseCompressed={() => applyCompressedCover(compressedBlob, originalFile.name)}
      />
    );
  }

  function renderCompressionError() {
    const { originalFile, error } = compression;
    if (!originalFile) return null;
    return (
      <div className="flex flex-col gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-3 text-sm">
        <p className="text-destructive">{error ?? "Could not compress this image."}</p>
        <Button
          className="self-start"
          size="sm"
          type="button"
          variant="outline"
          onClick={() => keepOriginalCover(originalFile)}
        >
          Use original image
        </Button>
      </div>
    );
  }

  function addTag(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter" || e.key === ",") {
      e.preventDefault();
      const tag = tagInput.trim().replace(/,$/, "");
      if (tag && !info.tags.includes(tag)) {
        onChange({ tags: [...info.tags, tag] });
      }
      setTagInput("");
    }
  }

  function removeTag(tag: string) {
    onChange({ tags: info.tags.filter((t) => t !== tag) });
  }

  return (
    <div className="form-stack max-w-2xl">
      {/* Title */}
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="title">Course title <span className="text-destructive">*</span></Label>
        <Input
          id="title"
          placeholder="e.g. Complete Go Backend Development"
          value={info.title}
          onChange={(e) => onChange({ title: e.target.value })}
        />
      </div>

      {/* Description */}
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="description">Description</Label>
        <Textarea
          className="resize-none"
          id="description"
          placeholder="What will students learn? Who is this for?"
          rows={4}
          value={info.description}
          onChange={(e) => onChange({ description: e.target.value })}
        />
      </div>

      {/* Cover image */}
      <div className="flex flex-col gap-2">
        <Label>Cover image</Label>
        <div className="flex gap-1 text-xs">
          {(["upload", "url"] as const).map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setCoverTab(t)}
              className={cn(
                "flex items-center gap-1 rounded px-2 py-1 transition-colors",
                coverTab === t ? "bg-muted font-medium" : "text-muted-foreground hover:text-foreground",
              )}
            >
              {t === "upload" ? <Upload className="h-3 w-3" /> : <LinkIcon className="h-3 w-3" />}
              {t === "upload" ? "Upload" : "Paste URL"}
            </button>
          ))}
        </div>

        {coverTab === "upload" ? (
          <label className="flex cursor-pointer flex-col items-center gap-2 rounded-md border-2 border-dashed border-border px-4 py-8 text-center hover:border-primary hover:bg-muted/40 transition-colors">
            <Upload className="h-6 w-6 text-muted-foreground" />
            <div>
              <p className="text-sm font-medium">Click to upload cover image</p>
              <p className="text-xs text-muted-foreground">PNG, JPG, WebP · Recommended 1280×720</p>
            </div>
            <input
              accept="image/*"
              className="sr-only"
              disabled={compression.status === "compressing"}
              type="file"
              onChange={(e) => {
                const f = e.target.files?.[0];
                e.target.value = "";
                if (f) void compression.compress(f);
              }}
            />
          </label>
        ) : (
          <Input
            placeholder="https://example.com/cover.jpg"
            type="url"
            value={info.cover_url}
            onChange={(e) => { onChange({ cover_url: e.target.value }); onCoverFile(null); compression.clear(); }}
          />
        )}

        {compression.status === "compressing" && (
          <div className="flex items-center gap-3 rounded-md border border-border p-3 text-sm text-muted-foreground">
            <Skeleton className="h-8 w-8 shrink-0 rounded-md" />
            Compressing image…
          </div>
        )}

        {compression.status === "ready" && renderCompressionPreview()}
        {compression.status === "error" && renderCompressionError()}

        {compression.status === "idle" && coverPreview && (
          <div className="relative">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              alt="Cover preview"
              className="h-40 w-full rounded-md object-cover bg-muted"
              src={coverPreview}
            />
            <Button
              aria-label="Remove cover image"
              className="absolute right-2 top-2 h-7 w-7 rounded-full"
              size="icon"
              type="button"
              variant="secondary"
              onClick={() => { onCoverFile(null); onChange({ cover_url: "" }); }}
            >
              <X className="h-3.5 w-3.5" />
            </Button>
          </div>
        )}
      </div>

      {/* Difficulty + Free */}
      <div className="grid-responsive-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="difficulty">Difficulty</Label>
          <Select value={info.difficulty} onValueChange={(v) => onChange({ difficulty: v })}>
            <SelectTrigger aria-label="Difficulty level" id="difficulty"><SelectValue /></SelectTrigger>
            <SelectContent>
              {COURSE_DIFFICULTY_OPTIONS.map((o) => (
                <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="flex flex-col justify-end gap-1.5 pb-0.5">
          <div className="flex items-center gap-2">
            <Checkbox
              id="is_free"
              checked={info.is_free}
              onCheckedChange={(v) => onChange({ is_free: Boolean(v) })}
            />
            <Label className="cursor-pointer font-normal" htmlFor="is_free">Free course</Label>
          </div>
        </div>
      </div>

      {/* Tags */}
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="tags">Tags</Label>
        <div className="flex flex-wrap gap-1.5 rounded-md border border-input bg-background px-3 py-2 min-h-[40px]">
          {info.tags.map((tag) => (
            <span key={tag} className="flex items-center gap-1 rounded bg-muted px-2 py-0.5 text-xs">
              {tag}
              <button aria-label={`Remove tag ${tag}`} type="button" onClick={() => removeTag(tag)}>
                <X className="h-3 w-3" />
              </button>
            </span>
          ))}
          <input
            className="flex-1 w-full bg-transparent text-sm outline-none placeholder:text-muted-foreground"
            id="tags"
            placeholder={info.tags.length ? "" : "Type a tag and press Enter…"}
            value={tagInput}
            onChange={(e) => setTagInput(e.target.value)}
            onKeyDown={addTag}
          />
        </div>
        <p className="text-xs text-muted-foreground">Press Enter or comma to add a tag</p>
      </div>
    </div>
  );
}
