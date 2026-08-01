"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { startCheckoutAction, previewCouponAction } from "@/lib/mentoring/actions";
import type { CouponPreview } from "@/lib/server/mentoring";
import { useMoney } from "@/lib/currency-context";
import ROUTES from "@/lib/routes";
import { RazorpayScript, openRazorpayCheckout } from "./razorpay-checkout";

interface PurchaseCourseButtonProps {
  courseId: string;
  courseSlug: string;
  priceCents: number;
}

// Starting a checkout never grants access by itself — a real gateway
// confirms asynchronously (3DS, redirect, bank debit clearing). Stripe hands
// back a redirect_url (this component just navigates there); Razorpay hands
// back client_params for its own Checkout.js modal (RazorpayCheckout).
// Either way, the actual "you're in" signal only ever comes from the
// checkout return page polling purchase-status once a webhook confirms it —
// see lib/mentoring/actions.ts's purchaseStatusAction and app/(app)/courses/
// [slug]/checkout/return/page.tsx.
//
// The purchase action lives in lib/mentoring/actions.ts, not
// lib/courses/actions.ts, since it is owned by the mentoring domain (paid
// courses auto-open a mentor ticket). This file is colocated in the route
// folder (not components/courses/) so it sits outside the
// eslint-plugin-boundaries feature graph, matching the existing
// remove-member-button.tsx pattern for route-local cross-feature composition.
export function PurchaseCourseButton({ courseId, courseSlug, priceCents }: PurchaseCourseButtonProps) {
  const [pending, setPending] = useState(false);
  const [coupon, setCoupon] = useState<{ code: string; preview: CouponPreview | null }>({ code: "", preview: null });
  const router = useRouter();
  const money = useMoney();

  async function handleApplyCoupon() {
    if (!coupon.code.trim()) return;
    setPending(true);
    const result = await previewCouponAction(courseId, coupon.code.trim());
    setPending(false);
    if (result.error || !result.data) {
      toast.error(result.error ?? "Invalid coupon code.");
      setCoupon((c) => ({ ...c, preview: null }));
      return;
    }
    const preview = result.data;
    setCoupon((c) => ({ ...c, preview }));
    toast.success(`Coupon applied — ${money(preview.final_amount_cents)}`);
  }

  async function handlePurchase() {
    setPending(true);
    // Any code left in the box is sent, applied or not — dropping an unapplied
    // one would silently charge full price for a code the student did enter.
    // The server re-validates it regardless of what Apply previewed.
    const result = await startCheckoutAction(courseId, {
      couponCode: coupon.code.trim() || undefined,
    });
    setPending(false);
    if (result.error || !result.data) {
      toast.error(result.error ?? "Could not start checkout.");
      return;
    }
    const session = result.data;
    if (session.status === "completed") {
      toast.success("Purchase complete. You're enrolled!");
      router.refresh();
      return;
    }
    if (session.redirect_url) {
      window.location.assign(session.redirect_url);
      return;
    }
    if (session.client_params) {
      openRazorpayCheckout(session.client_params, {
        onSuccess: () => router.push(ROUTES.courseCheckoutReturn(courseSlug)),
        onClose: () => {},
      });
      return;
    }
    toast.error("Checkout could not be started.");
  }

  const finalCents = coupon.preview ? coupon.preview.final_amount_cents : priceCents;

  return (
    <div className="flex flex-col gap-3">
      <RazorpayScript />
      <div className="stack-sm">
        <Input
          disabled={pending || Boolean(coupon.preview)}
          placeholder="Coupon code"
          value={coupon.code}
          onChange={(e) => setCoupon({ code: e.target.value, preview: null })}
        />
        <Button
          disabled={pending || !coupon.code.trim() || Boolean(coupon.preview)}
          type="button"
          variant="outline"
          onClick={handleApplyCoupon}
        >
          Apply
        </Button>
      </div>
      <Button className="w-full" disabled={pending} size="lg" onClick={handlePurchase}>
        {pending ? "Processing…" : `Buy for ${money(finalCents)}`}
      </Button>
    </div>
  );
}
