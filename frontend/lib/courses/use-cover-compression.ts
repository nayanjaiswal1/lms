"use client";

import { useCallback, useState } from "react";
import { compressImage } from "@/lib/courses/compress-image";

export type CoverCompressionStatus = "idle" | "compressing" | "ready" | "error";

interface CoverCompressionState {
  status:               CoverCompressionStatus;
  originalFile:         File | null;
  originalPreviewUrl:   string | null;
  compressedBlob:       Blob | null;
  compressedSize:       number;
  compressedPreviewUrl: string | null;
  width:                number;
  height:               number;
  error:                string | null;
}

const INITIAL_STATE: CoverCompressionState = {
  status:               "idle",
  originalFile:         null,
  originalPreviewUrl:   null,
  compressedBlob:       null,
  compressedSize:       0,
  compressedPreviewUrl: null,
  width:                0,
  height:               0,
  error:                null,
};

function revokePreviewUrls(state: CoverCompressionState) {
  if (state.originalPreviewUrl) URL.revokeObjectURL(state.originalPreviewUrl);
  if (state.compressedPreviewUrl) URL.revokeObjectURL(state.compressedPreviewUrl);
}

/**
 * Runs a newly selected cover image through client-side compression and
 * holds a before/after preview until the caller confirms which version
 * (compressed or original) to commit. Object URLs are created once per
 * compression run and revoked on clear()/re-run, rather than recreated on
 * every render. Single useState keeps this within the project's per-file
 * state budget.
 */
export function useCoverCompression() {
  const [state, setState] = useState<CoverCompressionState>(INITIAL_STATE);

  const compress = useCallback(async (file: File) => {
    setState((prev) => {
      revokePreviewUrls(prev);
      return { ...INITIAL_STATE, status: "compressing", originalFile: file };
    });
    try {
      const result = await compressImage(file);
      setState({
        status:               "ready",
        originalFile:         file,
        originalPreviewUrl:   URL.createObjectURL(file),
        compressedBlob:       result.blob,
        compressedSize:       result.blob.size,
        compressedPreviewUrl: URL.createObjectURL(result.blob),
        width:                result.width,
        height:               result.height,
        error:                null,
      });
    } catch (err) {
      setState({
        ...INITIAL_STATE,
        status: "error",
        originalFile: file,
        error: err instanceof Error ? err.message : "Could not compress image.",
      });
    }
  }, []);

  const clear = useCallback(() => {
    setState((prev) => {
      revokePreviewUrls(prev);
      return INITIAL_STATE;
    });
  }, []);

  return { ...state, compress, clear };
}
