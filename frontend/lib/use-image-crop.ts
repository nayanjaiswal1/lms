import { useRef, useState } from "react"

const MIN_ZOOM = 1
const MAX_ZOOM = 3
const OUTPUT_SIZE = 512

interface Pan {
  x: number
  y: number
}

/**
 * Drives a pan/zoom square-crop preview. Pan is kept in a ref (not state) and
 * applied to the image directly via the DOM so dragging stays at pointer
 * frame rate instead of re-rendering React on every pointermove.
 */
export function useImageCrop(viewportSize: number) {
  const [natural, setNatural] = useState<{ w: number; h: number } | null>(null)
  const [zoom, setZoom] = useState(MIN_ZOOM)

  const imgRef = useRef<HTMLImageElement>(null)
  const panRef = useRef<Pan>({ x: 0, y: 0 })
  const dragRef = useRef<{ active: boolean; startX: number; startY: number; startPan: Pan }>({
    active: false,
    startX: 0,
    startY: 0,
    startPan: { x: 0, y: 0 },
  })

  function displayScale(z: number, dims: { w: number; h: number }) {
    return (viewportSize / Math.min(dims.w, dims.h)) * z
  }

  function maxPan(z: number, dims: { w: number; h: number }) {
    const scale = displayScale(z, dims)
    return {
      x: Math.max(0, (dims.w * scale - viewportSize) / 2),
      y: Math.max(0, (dims.h * scale - viewportSize) / 2),
    }
  }

  function applyTransform(z: number, pan: Pan, dims: { w: number; h: number }) {
    const el = imgRef.current
    if (!el) return
    const scale = displayScale(z, dims)
    el.style.width = `${dims.w * scale}px`
    el.style.height = `${dims.h * scale}px`
    el.style.left = `calc(50% + ${pan.x}px)`
    el.style.top = `calc(50% + ${pan.y}px)`
  }

  function clampPan(pan: Pan, z: number, dims: { w: number; h: number }): Pan {
    const bound = maxPan(z, dims)
    return {
      x: Math.min(bound.x, Math.max(-bound.x, pan.x)),
      y: Math.min(bound.y, Math.max(-bound.y, pan.y)),
    }
  }

  function handleImageLoad(e: React.SyntheticEvent<HTMLImageElement>) {
    const dims = { w: e.currentTarget.naturalWidth, h: e.currentTarget.naturalHeight }
    setNatural(dims)
    panRef.current = { x: 0, y: 0 }
    applyTransform(MIN_ZOOM, panRef.current, dims)
  }

  function handleZoomChange(values: number[]) {
    const z = values[0]
    if (!natural) return
    const clamped = clampPan(panRef.current, z, natural)
    panRef.current = clamped
    setZoom(z)
    applyTransform(z, clamped, natural)
  }

  function handlePointerDown(e: React.PointerEvent) {
    e.currentTarget.setPointerCapture(e.pointerId)
    dragRef.current = {
      active: true,
      startX: e.clientX,
      startY: e.clientY,
      startPan: { ...panRef.current },
    }
  }

  function handlePointerMove(e: React.PointerEvent) {
    if (!dragRef.current.active || !natural) return
    const dx = e.clientX - dragRef.current.startX
    const dy = e.clientY - dragRef.current.startY
    const next = clampPan(
      { x: dragRef.current.startPan.x + dx, y: dragRef.current.startPan.y + dy },
      zoom,
      natural,
    )
    panRef.current = next
    applyTransform(zoom, next, natural)
  }

  function handlePointerUp() {
    dragRef.current.active = false
  }

  /** Renders the current crop selection onto an OUTPUT_SIZE square JPEG blob. */
  async function getCroppedBlob(): Promise<Blob | null> {
    const img = imgRef.current
    if (!img || !natural) return null

    const k = OUTPUT_SIZE / viewportSize
    const scale = displayScale(zoom, natural)
    const dw = natural.w * scale
    const dh = natural.h * scale
    const destX = (viewportSize - dw) / 2 + panRef.current.x
    const destY = (viewportSize - dh) / 2 + panRef.current.y

    const canvas = document.createElement("canvas")
    canvas.width = OUTPUT_SIZE
    canvas.height = OUTPUT_SIZE
    const ctx = canvas.getContext("2d")
    if (!ctx) return null

    ctx.drawImage(img, 0, 0, natural.w, natural.h, destX * k, destY * k, dw * k, dh * k)

    return new Promise((resolve) => canvas.toBlob((blob) => resolve(blob), "image/jpeg", 0.92))
  }

  return {
    imgRef,
    zoom,
    minZoom: MIN_ZOOM,
    maxZoom: MAX_ZOOM,
    isReady: natural !== null,
    handleImageLoad,
    handleZoomChange,
    handlePointerDown,
    handlePointerMove,
    handlePointerUp,
    getCroppedBlob,
  }
}
