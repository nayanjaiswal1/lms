import type { Metadata } from "next";
import Link from "next/link";

import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How MindForge collects, uses, and protects your personal data.",
};

const LAST_UPDATED = "August 4, 2026";

export default function PrivacyPage() {
  return (
    // eslint-disable-next-line no-restricted-syntax -- standalone public page outside the (app) shell, no .app-content ancestor to supply vertical padding
    <main className="page-container-sm py-12">
      <h1 className="page-title">Privacy Policy</h1>
      <p className="text-sm text-muted-foreground">Last updated: {LAST_UPDATED}</p>

      <div className="prose-content mt-8">
        <p>
          This Privacy Policy explains what personal data MindForge collects, why, and the rights
          you have over it, including under India&apos;s Digital Personal Data Protection Act, 2023
          (&quot;DPDP Act&quot;) and, where applicable, the EU General Data Protection Regulation
          (&quot;GDPR&quot;).
        </p>

        <h2>1. What We Collect</h2>
        <ul>
          <li>Account data: name, email, password hash, avatar.</li>
          <li>Usage data: course progress, quiz attempts, lab sessions, wiki/project activity.</li>
          <li>Payment data: purchase amount, currency, and status — card/UPI details are handled
            directly by our payment processors (Stripe, Razorpay); we never see or store them.</li>
          <li>Technical data: a truncated IP address (first three octets) and device hint, kept
            only for session security and fraud detection.</li>
        </ul>

        <h2>2. Why We Collect It</h2>
        <p>
          To operate your account and deliver course content, to secure sessions and detect
          suspicious sign-ins, to process payments, to respond to support requests, and to meet
          legal obligations (e.g. maintaining a record of your consent to these policies).
        </p>

        <h2>3. Your Rights</h2>
        <p>
          You can review and correct your profile at any time from your account settings. You can
          request a copy of your personal data or request deletion of your account from{" "}
          <Link href={ROUTES.SETTINGS_PRIVACY}>Settings → Privacy</Link>. Deleting your account
          anonymizes your personal information (name, email, avatar, password) immediately and
          signs you out of every device; content you authored that other users depend on (e.g. a
          published course module) is not deleted, only disassociated from your identity.
        </p>

        <h2>4. Data Sharing</h2>
        <p>
          We share data only with the processors needed to run the platform: payment gateways
          (Stripe/Razorpay), email delivery, and, if your organization enables it, single sign-on
          providers. We do not sell personal data.
        </p>

        <h2>5. Data Retention</h2>
        <p>
          We keep account and usage data for as long as your account is active. Consent records
          (see below) are kept indefinitely as an audit trail even after account deletion, since
          they contain no personal data once your account has been anonymized.
        </p>

        <h2>6. Consent Records</h2>
        <p>
          We record which version of this Privacy Policy and the{" "}
          <Link href={ROUTES.LEGAL_TERMS}>Terms of Service</Link> you accepted, and when. If we
          materially change either document, you will be asked to review and accept the new
          version before continuing to use MindForge.
        </p>

        <h2>7. Contact</h2>
        <p>
          Questions about this policy or a data request can be raised through the in-app support
          ticket system.
        </p>
      </div>
    </main>
  );
}
