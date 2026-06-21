"use client"

import { useRef, useState } from "react"
import { Camera } from "lucide-react"
import { cn } from "@/lib/utils"

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
  const [preview, setPreview] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const formRef = useRef<HTMLFormElement>(null)

  const { outer, text, icon } = SIZE_MAP[size]
  const displaySrc = preview ?? avatarUrl

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setPreview(URL.createObjectURL(file))
    formRef.current?.requestSubmit()
  }

  return (
    <div className={cn("relative shrink-0", outer)}>
      {displaySrc ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          alt={`${name} avatar`}
          className={cn("rounded-full object-cover w-full h-full")}
          src={displaySrc}
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
        <form action={uploadAction} ref={formRef}>
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
        </form>
      )}
    </div>
  )
}
