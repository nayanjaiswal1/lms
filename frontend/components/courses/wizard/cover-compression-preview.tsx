"use client";

import { Button } from "@/components/ui/button";
import { formatBytes } from "@/lib/utils";

interface CoverCompressionPreviewProps {
  originalPreviewUrl:   string;
  originalSize:         number;
  compressedPreviewUrl: string;
  compressedSize:       number;
  width:                number;
  height:               number;
  onUseCompressed:      () => void;
  onKeepOriginal:       () => void;
}

export function CoverCompressionPreview({
  originalPreviewUrl, originalSize, compressedPreviewUrl, compressedSize, width, height,
  onUseCompressed, onKeepOriginal,
}: CoverCompressionPreviewProps) {
  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-muted/30 p-3">
      <p className="text-sm font-medium">Compressed preview · {width}×{height}px</p>
      <div className="grid-responsive-2 gap-3">
        <div className="flex flex-col gap-1.5">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            alt="Original cover image"
            className="h-28 w-full rounded-md object-cover bg-muted"
            src={originalPreviewUrl}
          />
          <p className="text-xs text-muted-foreground">Original · {formatBytes(originalSize)}</p>
        </div>
        <div className="flex flex-col gap-1.5">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            alt="Compressed cover image"
            className="h-28 w-full rounded-md object-cover bg-muted"
            src={compressedPreviewUrl}
          />
          <p className="text-xs text-muted-foreground">Compressed · {formatBytes(compressedSize)}</p>
        </div>
      </div>
      <div className="flex flex-wrap gap-2">
        <Button type="button" onClick={onUseCompressed}>Use compressed</Button>
        <Button type="button" variant="outline" onClick={onKeepOriginal}>Keep original</Button>
      </div>
    </div>
  );
}
