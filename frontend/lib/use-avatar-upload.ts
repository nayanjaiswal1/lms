import { useRef, useState } from "react"

const MAX_AVATAR_BYTES = 5 * 1024 * 1024
const ACCEPTED_TYPES = ["image/jpeg", "image/png"]

interface Options {
  uploadAction: (formData: FormData) => Promise<void>
}

/** Owns the select → crop → upload flow for a single avatar input. */
export function useAvatarUpload({ uploadAction }: Options) {
  const [preview, setPreview] = useState<string | null>(null)
  const [loadFailed, setLoadFailed] = useState(false)
  const [pendingFile, setPendingFile] = useState<File | null>(null)
  const [isUploading, setIsUploading] = useState(false)

  const inputRef = useRef<HTMLInputElement>(null)

  function resetInput() {
    if (inputRef.current) inputRef.current.value = ""
  }

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return

    if (!ACCEPTED_TYPES.includes(file.type) || file.size > MAX_AVATAR_BYTES) {
      resetInput()
      return
    }

    setPendingFile(file)
  }

  function handleCropCancel() {
    setPendingFile(null)
    resetInput()
  }

  async function handleCropConfirm(blob: Blob) {
    setPendingFile(null)
    resetInput()
    setLoadFailed(false)
    setPreview(URL.createObjectURL(blob))

    const formData = new FormData()
    formData.append("avatar", new File([blob], "avatar.jpg", { type: "image/jpeg" }))

    setIsUploading(true)
    try {
      await uploadAction(formData)
    } finally {
      setIsUploading(false)
    }
  }

  return {
    preview,
    loadFailed,
    setLoadFailed,
    pendingFile,
    isUploading,
    inputRef,
    handleFileChange,
    handleCropCancel,
    handleCropConfirm,
  }
}
