"use client";

import { useRef, useTransition } from "react";
import { Paperclip, Send } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { createCapturesAction, uploadCapturesAction } from "@/app/(app)/captures/actions";

// One or more lines that all look like http(s) URLs -> one link item each.
// Anything else -> the whole paste is one raw-HTML/text item (splitting a
// single pasted HTML document by newline would break it apart).
function itemsFromPaste(text: string): string[] {
  const lines = text.split("\n").map((l) => l.trim()).filter(Boolean);
  const allLinks = lines.length > 0 && lines.every((l) => l.startsWith("http://") || l.startsWith("https://"));
  return allLinks ? lines : [text.trim()];
}

// Two ways in: pick files (screenshots/PDFs, multiple at once) or paste
// text (one or more links, one per line, or a single raw-HTML blob). Both
// hit the same POST /api/captures batch endpoint — see docs/captures.md.
export function CaptureUploadForm() {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const pasteRef = useRef<HTMLTextAreaElement>(null);
  const [isPending, startTransition] = useTransition();

  function onFilesSelected() {
    const files = fileInputRef.current?.files;
    if (!files || files.length === 0) return;
    const formData = new FormData();
    for (const file of Array.from(files)) formData.append("file", file);

    startTransition(async () => {
      const result = await uploadCapturesAction(formData);
      if (fileInputRef.current) fileInputRef.current.value = "";
      if (!result.ok) {
        toast.error(result.error ?? "Couldn't upload those files.");
        return;
      }
      toast.success(`${result.data?.length ?? 0} capture(s) added — reading them now.`);
    });
  }

  function onPasteSubmit() {
    const text = pasteRef.current?.value.trim() ?? "";
    if (!text) return;
    const items = itemsFromPaste(text);

    startTransition(async () => {
      const result = await createCapturesAction(items);
      if (!result.ok) {
        toast.error(result.error ?? "Couldn't save that.");
        return;
      }
      if (pasteRef.current) pasteRef.current.value = "";
      toast.success(`${result.data?.length ?? 0} capture(s) added — reading them now.`);
    });
  }

  return (
    <div className="card-base flex flex-col gap-3 p-4">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-start">
        <Textarea
          className="min-h-20 flex-1"
          disabled={isPending}
          placeholder="Paste a link (one per line for several), or paste raw HTML you copied from a page…"
          ref={pasteRef}
        />
        <div className="flex gap-2 sm:flex-col">
          <Button disabled={isPending} type="button" onClick={onPasteSubmit}>
            <Send aria-hidden className="size-4" />
            Add
          </Button>
          <Button
            className="touch-target"
            disabled={isPending}
            type="button"
            variant="outline"
            onClick={() => fileInputRef.current?.click()}
          >
            <Paperclip aria-hidden className="size-4" />
            Files
          </Button>
        </div>
      </div>
      <input
        multiple
        accept="image/jpeg,image/png,image/webp,application/pdf"
        className="hidden"
        ref={fileInputRef}
        type="file"
        onChange={onFilesSelected}
      />
      <p className="text-xs text-muted-foreground">
        Screenshots, PDFs, links, or pasted page HTML — up to 20 at once. Each one is read and
        sorted into a journal note or a flashcard automatically.
      </p>
    </div>
  );
}
