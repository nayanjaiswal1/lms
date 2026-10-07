import type { Metadata } from "next";
import Link from "next/link";

import { LegalPage } from "@/components/legal/legal-page";
import { grievanceContact } from "@/lib/legal-constants";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Grievance Redressal",
  description: "How to raise a grievance or data request with MindForge.",
};

export default function GrievancePage() {
  const officer = grievanceContact();
  return (
    <LegalPage title="Grievance Redressal">
      <p>
        If you have a complaint about how MindForge handles your personal data, or a request to
        access, correct or delete it, contact our Grievance Officer.
      </p>

      <h2>Grievance Officer</h2>
      {officer ? (
        <p>
          {officer.name}
          <br />
          <a href={`mailto:${officer.email}`}>{officer.email}</a>
        </p>
      ) : (
        <p>
          The Grievance Officer&apos;s contact details are not configured on this deployment. Use
          the in-app support ticket system in the meantime.
        </p>
      )}

      <h2>Other Ways to Reach Us</h2>
      <ul>
        <li>The in-app support ticket system, from the Support page after you sign in.</li>
        <li>
          Self-service data download and account deletion under Settings → Privacy (see the{" "}
          <Link href={ROUTES.LEGAL_PRIVACY}>Privacy Policy</Link>).
        </li>
      </ul>

      <h2>What to Include</h2>
      <p>
        The email address on your account and a description of the issue or request, so we can
        locate your data. Do not send passwords.
      </p>
    </LegalPage>
  );
}
