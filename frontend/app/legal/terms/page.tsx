import type { Metadata } from "next";
import Link from "next/link";

import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Terms of Service",
  description: "The terms that govern your use of MindForge.",
};

const LAST_UPDATED = "August 4, 2026";

export default function TermsPage() {
  return (
    // eslint-disable-next-line no-restricted-syntax -- standalone public page outside the (app) shell, no .app-content ancestor to supply vertical padding
    <main className="page-container-sm py-12">
      <h1 className="page-title">Terms of Service</h1>
      <p className="text-sm text-muted-foreground">Last updated: {LAST_UPDATED}</p>

      <div className="prose-content mt-8">
        <p>
          These Terms of Service (&quot;Terms&quot;) govern your access to and use of MindForge
          (&quot;MindForge&quot;, &quot;we&quot;, &quot;us&quot;). By creating an account or otherwise using the
          platform, you agree to these Terms. If you do not agree, do not use MindForge.
        </p>

        <h2>1. Accounts</h2>
        <p>
          You are responsible for the accuracy of the information you provide and for keeping
          your credentials secure. You must be at least 13 years old to create an account. If you
          are under the age of majority in your jurisdiction, a parent or guardian must consent to
          these Terms on your behalf.
        </p>

        <h2>2. Content You Submit</h2>
        <p>
          You retain ownership of content you create on MindForge (wiki pages, course submissions,
          projects, comments). By posting it, you grant MindForge a license to host, display, and
          distribute it as needed to operate the platform. You are solely responsible for content
          you submit and must not upload anything illegal, infringing, or that you do not have the
          right to share. See our <Link href={ROUTES.LEGAL_PRIVACY}>Privacy Policy</Link> for how
          we handle personal data, and report violations through the in-app &quot;Report&quot; action on
          any piece of content.
        </p>

        <h2>3. Paid Courses &amp; Refunds</h2>
        <p>
          Course purchases are billed in INR through our payment processors. Our cancellation and
          refund terms are set out separately in the{" "}
          <Link href={ROUTES.LEGAL_REFUND_POLICY}>Refund Policy</Link>, which forms part of these
          Terms.
        </p>

        <h2>4. Acceptable Use</h2>
        <p>
          You must not use MindForge to violate any law, infringe anyone&apos;s rights, distribute
          malware, attempt to gain unauthorized access to other accounts or infrastructure, or
          interfere with the platform&apos;s normal operation (including automated scraping,
          load-testing production systems, or circumventing rate limits).
        </p>

        <h2>5. Suspension &amp; Termination</h2>
        <p>
          We may suspend or deactivate an account that violates these Terms, is found to host
          illegal or infringing content, or on your own request (see{" "}
          <Link href={ROUTES.SETTINGS_PRIVACY}>Settings → Privacy</Link> to delete your account).
        </p>

        <h2>6. Disclaimers &amp; Liability</h2>
        <p>
          MindForge is provided &quot;as is&quot; without warranties of any kind. To the maximum extent
          permitted by law, MindForge is not liable for indirect, incidental, or consequential
          damages arising from your use of the platform.
        </p>

        <h2>7. Changes to These Terms</h2>
        <p>
          We may update these Terms from time to time. When we do, the &quot;Last updated&quot; date above
          changes and you will be asked to review and re-accept the new version the next time you
          sign in.
        </p>

        <h2>8. Contact</h2>
        <p>
          Questions about these Terms can be raised through the in-app support ticket system.
        </p>
      </div>
    </main>
  );
}
