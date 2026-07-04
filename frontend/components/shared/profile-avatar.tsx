"use client"

import { Camera } from "lucide-react"
import { cn } from "@/lib/utils"
import { useAvatarUpload } from "@/lib/use-avatar-upload"
import { AvatarCropDialog } from "@/components/shared/avatar-crop-dialog"

interface Props {
  avatarUrl: string | null
  name: string
  size?: "sm" | "md" | "lg"
  editable?: boolean
  uploadAction?: (formData: FormData) => Promise<void>
}

const SIZE_MAP = {
  sm: { outer: "w-10 h-10",  text: "text-sm",  icon: 14 },
  md: { outer: "w-16 h-16",  text: "text-lg",  icon: 16 },
  lg: { outer: "w-24 h-24",  text: "text-2xl", icon: 18 },
} as const

function getInitials(name: string): string {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0].toUpperCase())
    .join("")
}

export function ProfileAvatar({
  avatarUrl,
  name,
  size = "lg",
  editable = false,
  uploadAction,
}: Props) {
  const {
    preview,
    loadFailed,
    setLoadFailed,
    pendingFile,
    inputRef,
    handleFileChange,
    handleCropCancel,
    handleCropConfirm,
  } = useAvatarUpload({ uploadAction: uploadAction ?? (async () => {}) })

  const { outer, text, icon } = SIZE_MAP[size]
  const displaySrc = preview ?? avatarUrl

  return (
    <div className={cn("relative shrink-0", outer)}>
      {displaySrc && !loadFailed ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          alt={`${name} avatar`}
          className={cn("rounded-full object-cover w-full h-full")}
          src={displaySrc}
          onError={() => setLoadFailed(true)}
        />
      ) : (
        <div
          aria-label={`${name} avatar`}
          className={cn(
            "rounded-full w-full h-full flex items-center justify-center",
            "bg-primary text-primary-foreground font-semibold select-none",
            text
          )}
        >
          {getInitials(name)}
        </div>
      )}

      {editable && uploadAction && (
        <>
          <input
            accept="image/jpeg,image/png"
            aria-label="Upload profile picture"
            className="sr-only"
            name="avatar"
            ref={inputRef}
            type="file"
            onChange={handleFileChange}
          />
          <button
            aria-label="Change profile picture"
            className={cn(
              "absolute bottom-0 right-0",
              "w-7 h-7 rounded-full",
              "bg-background border border-border",
              "flex items-center justify-center",
              "hover:bg-muted transition-colors duration-fast",
              "touch-target"
            )}
            type="button"
            onClick={() => inputRef.current?.click()}
          >
            <Camera className="text-foreground" size={icon} />
          </button>
          <AvatarCropDialog
            file={pendingFile}
            onCancel={handleCropCancel}
            onConfirm={handleCropConfirm}
          />
        </>
      )}
    </div>
  )
}
