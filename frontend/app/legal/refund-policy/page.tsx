import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Refund & Cancellation Policy",
  description: "MindForge's refund and cancellation terms for paid courses.",
};

const LAST_UPDATED = "August 4, 2026";

export default function RefundPolicyPage() {
  return (
    // eslint-disable-next-line no-restricted-syntax -- standalone public page outside the (app) shell, no .app-content ancestor to supply vertical padding
    <main className="page-container-sm py-12">
      <h1 className="page-title">Refund &amp; Cancellation Policy</h1>
      <p className="text-sm text-muted-foreground">Last updated: {LAST_UPDATED}</p>

      <div className="prose-content mt-8">
        <p>
          This policy is published in accordance with India&apos;s Consumer Protection
          (E-Commerce) Rules, 2020, and applies to every paid course purchased on MindForge.
        </p>

        <h2>1. How Refunds Work</h2>
        <p>
          MindForge does not auto-approve refunds. To request one, raise a support ticket from
          the &quot;Billing&quot; category with your purchase details. Our support team reviews each
          request individually — this protects both students acting in good faith and the
          instructors whose course fees fund their work.
        </p>

        <h2>2. When a Refund Is Typically Granted</h2>
        <ul>
          <li>You were charged more than once for the same course purchase.</li>
          <li>The course was materially different from its published description.</li>
          <li>A technical failure on our end prevented you from accessing the course content.</li>
        </ul>

        <h2>3. When a Refund Is Typically Not Granted</h2>
        <ul>
          <li>You have completed a substantial portion of the course content.</li>
          <li>The request is made outside a reasonable window after purchase.</li>
          <li>You simply changed your mind after meaningfully accessing paid material.</li>
        </ul>

        <h2>4. Processing Time</h2>
        <p>
          Approved refunds are issued back to your original payment method through our payment
          processor (Stripe or Razorpay) and typically settle within 5–10 business days,
          depending on your bank or card issuer.
        </p>

        <h2>5. Cancelling Before Payment Confirms</h2>
        <p>
          If you close the checkout page before completing payment, no charge occurs and no
          course access is granted — nothing further is needed on your part.
        </p>
      </div>
    </main>
  );
}
