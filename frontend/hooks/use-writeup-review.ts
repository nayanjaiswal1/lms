"use client"

import { useState, useTransition } from "react"
import { reviewLabWriteupAction } from "@/app/(app)/labs/[labId]/actions"
import { DEBUG_WRITEUP_MAX_REVIEWS, type WriteupReviewResult } from "@/lib/labs/kinds/debug"

interface WriteupState {
  result: WriteupReviewResult | null
  error: string | null
  /** Set once the backend says the per-session review cap is reached. */
  exhausted: boolean
}

/** "Submit write-up": AI review of INCIDENT.md (≤ 3 reviews per session). */
export function useWriteupReview(onReviewed: (result: WriteupReviewResult) => void) {
  const [state, setState] = useState<WriteupState>({ result: null, error: null, exhausted: false })
  const [isReviewing, startReview] = useTransition()

  function submit(sessionId: string) {
    startReview(async () => {
      const res = await reviewLabWriteupAction(sessionId)
      if (res.status === 429) {
        setState((prev) => ({ ...prev, error: null, exhausted: true }))
        return
      }
      if (!res.ok || !res.data) {
        setState((prev) => ({
          ...prev,
          error:
            res.status === 503
              ? "The AI reviewer is unavailable right now. Try again in a minute."
              : (res.error ?? "Could not review your write-up."),
        }))
        return
      }
      setState({ result: res.data, error: null, exhausted: res.data.reviews_remaining <= 0 })
      onReviewed(res.data)
    })
  }

  const remaining = state.exhausted
    ? 0
    : (state.result?.reviews_remaining ?? DEBUG_WRITEUP_MAX_REVIEWS)

  return { ...state, remaining, isReviewing, submit }
}
