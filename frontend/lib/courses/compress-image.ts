const DEFAULT_MAX_DIM = 1600;
const DEFAULT_TARGET_BYTES = 500_000;
const DEFAULT_MIN_QUALITY = 0.5;
const QUALITY_STEP = 0.1;
const QUALITY_EPSILON = 1e-6;

export interface CompressImageOptions {
  maxDim?: number;
  targetBytes?: number;
  minQuality?: number;
}

export interface CompressImageResult {
  blob: Blob;
  width: number;
  height: number;
  originalSize: number;
}

/**
 * Resizes and re-encodes an image entirely in the browser (createImageBitmap
 * + canvas), stepping quality down until the target byte size is met or the
 * quality floor is hit. Prefers WebP; falls back to JPEG when a browser's
 * canvas implementation cannot encode WebP (toBlob returns null).
 */
export async function compressImage(
  file: File,
  opts?: CompressImageOptions,
): Promise<CompressImageResult> {
  const maxDim = opts?.maxDim ?? DEFAULT_MAX_DIM;
  const targetBytes = opts?.targetBytes ?? DEFAULT_TARGET_BYTES;
  const minQuality = opts?.minQuality ?? DEFAULT_MIN_QUALITY;

  const bitmap = await createImageBitmap(file);
  let width: number;
  let height: number;
  let blob: Blob | null;
  try {
    const scale = Math.min(1, maxDim / Math.max(bitmap.width, bitmap.height));
    width = Math.max(1, Math.round(bitmap.width * scale));
    height = Math.max(1, Math.round(bitmap.height * scale));

    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Canvas 2D context is not available in this browser.");
    ctx.drawImage(bitmap, 0, 0, width, height);

    blob = await encodeAtDecreasingQuality(canvas, "image/webp", targetBytes, minQuality);
    if (!blob) {
      blob = await encodeAtDecreasingQuality(canvas, "image/jpeg", targetBytes, minQuality);
    }
  } finally {
    bitmap.close();
  }

  if (!blob) throw new Error("Image encoding is not supported in this browser.");

  return { blob, width, height, originalSize: file.size };
}

function canvasToBlob(canvas: HTMLCanvasElement, type: string, quality: number): Promise<Blob | null> {
  return new Promise((resolve) => {
    canvas.toBlob((result) => resolve(result), type, quality);
  });
}

/**
 * Encodes the canvas at `quality`, stepping down by QUALITY_STEP until the
 * blob is under `targetBytes` or `minQuality` is reached. Returns null (no
 * throw) when the browser's canvas cannot encode `type` at all, so the
 * caller can fall back to a different mime type.
 */
async function encodeAtDecreasingQuality(
  canvas: HTMLCanvasElement,
  type: string,
  targetBytes: number,
  minQuality: number,
): Promise<Blob | null> {
  let quality = 0.9;
  let best: Blob | null = null;

  while (quality >= minQuality - QUALITY_EPSILON) {
    const blob = await canvasToBlob(canvas, type, quality);
    if (!blob) return best;
    best = blob;
    if (blob.size <= targetBytes) return blob;
    quality = Math.round((quality - QUALITY_STEP) * 100) / 100;
  }

  return best;
}
