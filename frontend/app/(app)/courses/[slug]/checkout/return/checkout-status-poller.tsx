"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { CheckCircle2, XCircle, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { purchaseStatusAction } from "@/lib/mentoring/actions";
import ROUTES from "@/lib/routes";

const POLL_INTERVAL_MS = 2000;
const MAX_ATTEMPTS = 15; // ~30s — comfortably past typical webhook delivery latency

type Status = "polling" | "completed" | "pending_timeout" | "failed";

interface Props {
  courseId: string;
  courseSlug: string;
  courseTitle: string;
}

// The gateway redirect that lands here never grants access by itself — only
// a webhook-confirmed purchase (courses.PurchaseStatus.status === "completed")
// does, which can arrive slightly after the redirect. This polls until that
// confirmation lands (or a well-past-typical-latency timeout), closing the
// redirect-vs-webhook race a naive "redirect = success" page would have.
export function CheckoutStatusPoller({ courseId, courseSlug, courseTitle }: Props) {
  const [status, setStatus] = useState<Status>("polling");

  useEffect(() => {
    let attempts = 0;
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout> | null = null;

    const poll = async () => {
      attempts += 1;
      const result = await purchaseStatusAction(courseId);
      if (cancelled) return;

      if (result.data?.status === "completed") {
        setStatus("completed");
        return;
      }
      if (result.data?.status === "failed") {
        setStatus("failed");
        return;
      }
      if (attempts >= MAX_ATTEMPTS) {
        setStatus("pending_timeout");
        return;
      }
      timer = setTimeout(poll, POLL_INTERVAL_MS);
    };

    void poll();

    return () => {
      cancelled = true;
      if (timer) clearTimeout(timer);
    };
  }, [courseId]);

  if (status === "completed") {
    return (
      <div className="card-base flex flex-col items-center gap-4 p-8 text-center">
        <CheckCircle2 aria-hidden className="h-12 w-12 text-success" />
        <div>
          <h1 className="section-title">You&apos;re enrolled!</h1>
          <p className="mt-1 text-muted-foreground">Payment confirmed for {courseTitle}.</p>
        </div>
        <Button asChild size="lg">
          <Link href={ROUTES.courseLearn(courseSlug)}>Start learning</Link>
        </Button>
      </div>
    );
  }

  if (status === "failed") {
    return (
      <div className="card-base flex flex-col items-center gap-4 p-8 text-center">
        <XCircle aria-hidden className="h-12 w-12 text-destructive" />
        <div>
          <h1 className="section-title">Payment failed</h1>
          <p className="mt-1 text-muted-foreground">Your payment for {courseTitle} could not be completed.</p>
        </div>
        <Button asChild size="lg" variant="outline">
          <Link href={ROUTES.course(courseSlug)}>Try again</Link>
        </Button>
      </div>
    );
  }

  if (status === "pending_timeout") {
    return (
      <div className="card-base flex flex-col items-center gap-4 p-8 text-center">
        <Loader2 aria-hidden className="h-12 w-12 animate-spin text-muted-foreground" />
        <div>
          <h1 className="section-title">Still confirming…</h1>
          <p className="mt-1 text-muted-foreground">
            Your payment was received but confirmation is taking longer than usual. Refresh in a moment.
          </p>
        </div>
        <Button size="lg" variant="outline" onClick={() => window.location.reload()}>
          Refresh
        </Button>
      </div>
    );
  }

  return (
    <div className="card-base flex flex-col items-center gap-4 p-8 text-center">
      <Loader2 aria-hidden className="h-12 w-12 animate-spin text-muted-foreground" />
      <div>
        <h1 className="section-title">Confirming your payment…</h1>
        <p className="mt-1 text-muted-foreground">This usually takes just a few seconds.</p>
      </div>
    </div>
  );
}
