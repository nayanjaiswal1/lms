import type { Metadata } from "next";
import Link from "next/link";

import { LegalPage } from "@/components/legal/legal-page";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Acceptable Use Policy",
  description: "What you may and may not do on MindForge.",
};

export default function AcceptableUsePage() {
  return (
    <LegalPage title="Acceptable Use Policy">
      <p>
        This policy applies to everyone using MindForge and supplements the{" "}
        <Link href={ROUTES.LEGAL_TERMS}>Terms of Service</Link>.
      </p>

      <h2>You May Not</h2>
      <ul>
        <li>Post illegal content, or content that infringes someone else&apos;s copyright.</li>
        <li>Harass, threaten or impersonate other people.</li>
        <li>Spam members, wikis, comments or support channels.</li>
        <li>Probe, scan or attack the platform, or access data that is not yours.</li>
        <li>
          Use labs, compilers or sandboxes to attack other systems, mine cryptocurrency, or relay
          network traffic.
        </li>
        <li>Cheat or help others cheat in assessments, or circumvent proctoring.</li>
        <li>Share your account or resell access to paid course content.</li>
        <li>Use automated means to scrape content or overload the service.</li>
      </ul>

      <h2>Reporting Content</h2>
      <p>
        Organization members can report wiki pages and course modules. Reports go to the
        organization&apos;s moderators, who can remove the content.
      </p>

      <h2>Enforcement</h2>
      <p>
        We may remove content, suspend or deactivate accounts, or suspend an organization that
        breaks this policy.
      </p>
    </LegalPage>
  );
}
