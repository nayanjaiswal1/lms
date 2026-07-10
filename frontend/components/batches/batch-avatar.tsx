"use client";

import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Camera, Trash2 } from "lucide-react";
import { cn } from "@/lib/utils";
import { useAvatarUpload } from "@/lib/use-avatar-upload";
import { AvatarCropDialog } from "@/components/shared/avatar-crop-dialog";
import { uploadBatchImageAction, deleteBatchImageAction } from "@/lib/batches/actions";

function hashHue(seed: string): number {
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash << 5) - hash + seed.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash) % 360;
}

function getInitials(name: string): string {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0].toUpperCase())
    .join("");
}

const SIZE_MAP = {
  sm: { outer: "h-10 w-10", text: "text-sm", icon: 14 },
  md: { outer: "h-14 w-14", text: "text-lg", icon: 16 },
  lg: { outer: "h-24 w-24", text: "text-2xl", icon: 18 },
} as const;

interface BatchAvatarProps {
  batchId: string;
  name: string;
  imageUrl?: string | null;
  size?: "sm" | "md" | "lg";
  /** Shows the upload/remove controls. Only meaningful for staff on the batch's own pages. */
  editable?: boolean;
}

export function BatchAvatar({ batchId, name, imageUrl = null, size = "sm", editable = false }: BatchAvatarProps) {
  const router = useRouter();

  const {
    preview,
    loadFailed,
    setLoadFailed,
    pendingFile,
    isUploading,
    inputRef,
    handleFileChange,
    handleCropCancel,
    handleCropConfirm,
  } = useAvatarUpload({
    uploadAction: async (formData) => {
      const result = await uploadBatchImageAction(batchId, formData);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success("Batch image updated.");
      router.refresh();
    },
  });

  async function handleRemove() {
    const result = await deleteBatchImageAction(batchId);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Batch image removed.");
    router.refresh();
  }

  const { outer, text, icon } = SIZE_MAP[size];
  const displaySrc = preview ?? imageUrl;
  const hue = hashHue(batchId);

  return (
    <div className={cn("relative shrink-0", outer)}>
      {displaySrc && !loadFailed ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          alt={`${name} cover`}
          className="h-full w-full rounded-full object-cover"
          src={displaySrc}
          onError={() => setLoadFailed(true)}
        />
      ) : (
        // ponytail: deterministic hash-based color, guarantees every batch without a
        // custom image still gets a stable, visually distinct fallback.
        <div
          aria-label={`${name} avatar`}
          className={cn(
            "flex h-full w-full items-center justify-center rounded-full font-semibold text-white select-none",
            text,
          )}
          style={{ backgroundColor: `hsl(${hue}, 55%, 40%)` }}
        >
          {getInitials(name)}
        </div>
      )}

      {editable && (
        <>
          <input
            accept="image/jpeg,image/png,image/webp"
            aria-label="Upload batch image"
            className="sr-only"
            name="avatar"
            ref={inputRef}
            type="file"
            onChange={handleFileChange}
          />
          <button
            aria-label="Change batch image"
            className="absolute bottom-0 right-0 flex h-7 w-7 items-center justify-center rounded-full border border-border bg-background hover:bg-muted transition-colors duration-fast touch-target disabled:opacity-50"
            disabled={isUploading}
            type="button"
            onClick={() => inputRef.current?.click()}
          >
            <Camera className="text-foreground" size={icon} />
          </button>
          {displaySrc && (
            <button
              aria-label="Remove batch image"
              className="absolute bottom-0 left-0 flex h-7 w-7 items-center justify-center rounded-full border border-border bg-background hover:bg-muted transition-colors duration-fast touch-target"
              type="button"
              onClick={handleRemove}
            >
              <Trash2 className="text-destructive" size={icon} />
            </button>
          )}
          <AvatarCropDialog file={pendingFile} onCancel={handleCropCancel} onConfirm={handleCropConfirm} />
        </>
      )}
    </div>
  );
}
