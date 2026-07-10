"use client";

import { useRef } from "react";
import Image from "next/image";
import { Maximize2 } from "lucide-react";
import { Button } from "@/components/ui/button";

interface LessonFigureProps {
  src: string;
  alt: string;
  caption?: string;
}

// Inline diagram card for lesson (notes) modules: bordered canvas with a
// fullscreen toggle, caption below. Client leaf — the surrounding lesson
// stays a server component.
export function LessonFigure({ src, alt, caption }: LessonFigureProps) {
  const figureRef = useRef<HTMLElement>(null);

  const toggleFullscreen = () => {
    const el = figureRef.current;
    if (!el) return;
    if (document.fullscreenElement) {
      void document.exitFullscreen();
    } else {
      void el.requestFullscreen();
    }
  };

  return (
    <figure
      className="overflow-hidden rounded-lg border border-border bg-card [&:fullscreen]:flex [&:fullscreen]:flex-col [&:fullscreen]:justify-center [&:fullscreen]:bg-background [&:fullscreen]:p-8"
      ref={figureRef}
    >
      <div className="flex justify-end px-2 py-1">
        <Button
          aria-label="Toggle fullscreen"
          className="touch-target text-muted-foreground"
          size="icon"
          variant="ghost"
          onClick={toggleFullscreen}
        >
          <Maximize2 aria-hidden className="h-4 w-4" />
        </Button>
      </div>
      <div className="relative aspect-video w-full">
        <Image
          fill
          alt={alt}
          className="object-contain"
          sizes="(max-width: 1024px) 100vw, 768px"
          src={src}
        />
      </div>
      {caption && (
        <figcaption className="border-t border-border px-4 py-2 text-center text-sm text-muted-foreground">
          {caption}
        </figcaption>
      )}
    </figure>
  );
}
