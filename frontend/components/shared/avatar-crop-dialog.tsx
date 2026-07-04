"use client"

import { useMemo } from "react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Slider } from "@/components/ui/slider"
import { useImageCrop } from "@/lib/use-image-crop"

const VIEWPORT_SIZE = 288

interface Props {
  file: File | null
  onConfirm: (blob: Blob) => void | Promise<void>
  onCancel: () => void
}

export function AvatarCropDialog({ file, onConfirm, onCancel }: Props) {
  // Object URLs for a locally-picked file are cheap and released on unload;
  // no cleanup effect needed since `file` only ever changes via a fresh pick.
  const src = useMemo(() => (file ? URL.createObjectURL(file) : null), [file])
  const crop = useImageCrop(VIEWPORT_SIZE)

  async function handleSave() {
    const blob = await crop.getCroppedBlob()
    if (blob) await onConfirm(blob)
  }

  return (
    <Dialog
      open={file !== null}
      onOpenChange={(open) => {
        if (!open) onCancel()
      }}
    >
      <DialogContent className="modal-responsive sm:max-w-md" showClose={false}>
        <DialogHeader>
          <DialogTitle>Adjust your photo</DialogTitle>
          <DialogDescription>Drag to reposition. Use the slider to zoom.</DialogDescription>
        </DialogHeader>

        <div className="flex justify-center py-2">
          {src && (
            <div
              aria-label="Drag to reposition photo"
              className="relative h-72 w-72 max-w-full touch-none select-none overflow-hidden rounded-full border border-border bg-muted"
              role="img"
              onPointerDown={crop.handlePointerDown}
              onPointerLeave={crop.handlePointerUp}
              onPointerMove={crop.handlePointerMove}
              onPointerUp={crop.handlePointerUp}
            >
              {/* eslint-disable-next-line @next/next/no-img-element -- needs a raw <img> ref for direct style/canvas manipulation during drag; next/image's wrapper doesn't expose that */}
              <img
                alt="Crop preview"
                className="absolute left-1/2 top-1/2 max-w-none -translate-x-1/2 -translate-y-1/2 cursor-grab active:cursor-grabbing"
                draggable={false}
                ref={crop.imgRef}
                src={src}
                onLoad={crop.handleImageLoad}
              />
            </div>
          )}
        </div>

        <div className="flex items-center gap-3 px-1">
          <span className="text-xs text-muted-foreground">Zoom</span>
          <Slider
            aria-label="Zoom photo"
            disabled={!crop.isReady}
            max={crop.maxZoom}
            min={crop.minZoom}
            step={0.01}
            value={[crop.zoom]}
            onValueChange={crop.handleZoomChange}
          />
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={onCancel}>
            Cancel
          </Button>
          <Button disabled={!crop.isReady} type="button" onClick={handleSave}>
            Save photo
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
