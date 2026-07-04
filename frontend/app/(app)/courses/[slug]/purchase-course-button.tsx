"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { purchaseCourseAction } from "@/lib/mentoring/actions";

interface PurchaseCourseButtonProps {
  courseId: string;
  priceCents: number;
}

// Paid courses open a mentor ticket automatically (unless the student already
// has an active mentor) — the purchase action lives in lib/mentoring/actions.ts,
// not lib/courses/actions.ts, since it is owned by the mentoring domain. This
// file is colocated in the route folder (not components/courses/) so it sits
// outside the eslint-plugin-boundaries feature graph, matching the existing
// remove-member-button.tsx pattern for route-local cross-feature composition.
export function PurchaseCourseButton({ courseId, priceCents }: PurchaseCourseButtonProps) {
  const [pending, setPending] = useState(false);
  const router = useRouter();

  async function handlePurchase() {
    setPending(true);
    const result = await purchaseCourseAction(courseId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(
      result.data?.ticket
        ? "Purchase complete — a mentor ticket has been opened for you."
        : "Purchase complete. You're enrolled!",
    );
    router.refresh();
  }

  return (
    <Button className="w-full" disabled={pending} size="lg" onClick={handlePurchase}>
      {pending ? "Processing…" : `Buy for $${(priceCents / 100).toFixed(2)}`}
    </Button>
  );
}
