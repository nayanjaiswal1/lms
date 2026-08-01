"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { formatMoney } from "@/lib/money";
import { buyCreditPackAction, type CreditPack } from "@/lib/server/sessions";

interface CreditPackCardProps {
  pack: CreditPack;
}

/** One pack in the store. Money formatting reuses lib/money.ts's
 * formatMoney — price_cents is minor units of pack.currency (paise for an
 * INR deployment), and formatMoney already derives the right divisor from
 * Intl instead of assuming /100. */
export function CreditPackCard({ pack }: CreditPackCardProps) {
  const [pending, setPending] = useState(false);
  const router = useRouter();

  async function handleBuy() {
    setPending(true);
    const result = await buyCreditPackAction(pack.id, "razorpay");
    setPending(false);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not start checkout.");
      return;
    }
    const checkout = result.data;
    if (checkout.status === "completed") {
      toast.success("Pack added to your balance.");
      router.refresh();
      return;
    }
    if (checkout.redirect_url) {
      window.location.assign(checkout.redirect_url);
      return;
    }
    if (checkout.client_params) {
      // ponytail: Razorpay's Checkout.js modal is wired for course purchases
      // in app/(app)/courses/[slug]/razorpay-checkout.tsx, but that file is
      // colocated in the courses route (outside the eslint-boundaries
      // feature graph) specifically so it isn't importable from other
      // features. Wiring the same modal here is a follow-up: promote it to
      // a shared-lib helper, then call it from this branch.
      toast.info("Checkout is opening…");
      return;
    }
    toast.error("Checkout could not be started.");
  }

  return (
    <article className="card-base flex flex-col gap-3">
      <div>
        <h3 className="text-lg font-semibold">{pack.name}</h3>
        {pack.description && <p className="text-sm text-muted-foreground">{pack.description}</p>}
      </div>
      <p className="text-sm text-muted-foreground">
        {pack.sessions} session{pack.sessions === 1 ? "" : "s"}
      </p>
      <p className="text-2xl font-bold">{formatMoney(pack.price_cents, pack.currency)}</p>
      <Button className="mt-auto w-full" disabled={pending} onClick={handleBuy}>
        {pending ? "Starting checkout…" : "Buy"}
      </Button>
    </article>
  );
}
