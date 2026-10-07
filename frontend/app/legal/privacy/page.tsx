import type { Metadata } from "next";
import Link from "next/link";

import { grievanceContact, PRIVACY_LAST_UPDATED, SUBPROCESSORS } from "@/lib/legal-constants";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How MindForge collects, uses, and protects your personal data.",
};

export default function PrivacyPage() {
  const grievance = grievanceContact();
  return (
    // eslint-disable-next-line no-restricted-syntax -- standalone public page outside the (app) shell, no .app-content ancestor to supply vertical padding
    <main className="page-container-sm py-12">
      <h1 className="page-title">Privacy Policy</h1>
      <p className="text-sm text-muted-foreground">Last updated: {PRIVACY_LAST_UPDATED}</p>

      <div className="prose-content mt-8">
        <p>
          This Privacy Policy explains what personal data MindForge collects, why, and the rights
          you have over it, including under India&apos;s Digital Personal Data Protection Act, 2023
          (&quot;DPDP Act&quot;).
        </p>

        <h2>1. What We Collect</h2>
        <ul>
          <li>Account data: name, email, password hash, avatar.</li>
          <li>Usage data: course progress, quiz attempts, lab sessions, wiki/project activity, and
            proctoring events during assessments.</li>
          <li>Content you create: diary entries, learning journal entries, habits and tasks,
            calendar events, notes, and files you upload as captures (screenshots, PDFs, links)
            together with the text extracted from them.</li>
          <li>AI interactions: prompts and responses from lab hints and feedback features, and the
            actions an AI assistant takes on your account if you connect one.</li>
          <li>Public test candidates: name, email and phone entered to take a public test.</li>
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
          download a copy of your personal data or request deletion of your account from{" "}
          <Link href={ROUTES.SETTINGS_PRIVACY}>Settings → Privacy</Link>. Deleting your account
          deletes your diary, journal, captures (including the stored files), habits, notes, calendar,
          revision cards, AI-assistant connections and action history, anonymizes your name, email,
          avatar and password, and signs you out of every device. We keep what the law or other
          people depend on: payment records, your consent records, assessment and enrolment records
          held by your organization, and content you authored that others rely on (such as a
          published course module), all disassociated from your identity.
        </p>

        <h3>AI processing consent</h3>
        <p>
          AI features that send your own content to an AI provider (reading captures, analysing
          diary and journal entries, Fix English) are off until you turn on AI processing in{" "}
          <Link href={ROUTES.SETTINGS_PRIVACY}>Settings → Privacy</Link>. You can withdraw consent
          there at any time; it applies to your next request.
        </p>
        <h3>Nominee</h3>
        <p>
          You can name a nominee in the same place, a person who may exercise your rights on your
          behalf if you die or become incapacitated. We store their name, relationship and contact
          details only for that purpose.
        </p>
        <h3>Age requirement</h3>
        <p>
          MindForge is for people aged 18 or older. When you register you declare that you are 18
          or over, and we record when you made that declaration.
        </p>

        <h2>4. Data Sharing and Processors</h2>
        <p>
          We share data only with the processors needed to run the platform, listed below. We do
          not sell personal data. Several processors are outside India (see Location).
        </p>
        <ul>
          {SUBPROCESSORS.map((p) => (
            <li key={p.name}>
              <strong>{p.name}</strong>: {p.purpose}. Data: {p.data}. Location: {p.location}.
            </li>
          ))}
        </ul>
        <p>
          AI features send the text or image you submit to the AI provider named above; they are
          used only for the feature you invoked.
        </p>

        <h2>5. Data Retention</h2>
        <p>
          We keep account and usage data for as long as your account is active. Some records are
          deleted automatically after a fixed period:
        </p>
        <ul>
          <li>Security events (sign-ins, password and passkey changes, data exports): 365 days.</li>
          <li>Audit logs: 730 days. Actions taken by a connected AI assistant: 180 days.</li>
          <li>Assessment proctoring events and XP history: 730 days.</li>
          <li>Lab AI hints and feedback: 180 days.</li>
          <li>Name, email and phone of public test candidates: 180 days.</li>
        </ul>
        <p>
          Payment records are kept as the law requires. Consent records (see below) are kept as an
          audit trail even after account deletion, since they contain no personal data once your
          account has been anonymized.
        </p>

        <h2>6. Consent Records</h2>
        <p>
          We record which version of this Privacy Policy and the{" "}
          <Link href={ROUTES.LEGAL_TERMS}>Terms of Service</Link> you accepted, and when. If we
          materially change either document, you will be asked to review and accept the new
          version before continuing to use MindForge.
        </p>

        <h2>7. Contact and Grievances</h2>
        <p>
          Questions about this policy or a data request can be raised through the in-app support
          ticket system.
        </p>
        {grievance && (
          <p>
            Grievance Officer: {grievance.name},{" "}
            <a href={`mailto:${grievance.email}`}>{grievance.email}</a>. You can write to this
            address without signing in.
          </p>
        )}
      </div>
    </main>
  );
}
