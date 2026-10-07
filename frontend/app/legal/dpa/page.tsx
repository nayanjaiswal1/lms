import type { Metadata } from "next";
import Link from "next/link";

import { LegalPage } from "@/components/legal/legal-page";
import { dpaContactEmail, SUBPROCESSORS } from "@/lib/legal-constants";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Data Processing",
  description: "Roles and sub-processors when an organization uses MindForge.",
};

export default function DpaPage() {
  const email = dpaContactEmail();
  return (
    <LegalPage title="Data Processing">
      <p>
        This page describes how personal data is handled when an organization uses MindForge for
        its members. For individual users, see the{" "}
        <Link href={ROUTES.LEGAL_PRIVACY}>Privacy Policy</Link>.
      </p>

      <h2>Roles</h2>
      <p>
        For members&apos; learning records, assessments and enrolment data held on behalf of an
        organization, the organization decides why and how the data is used and MindForge processes
        it on the organization&apos;s behalf. For account, security and billing data, MindForge
        determines the purposes.
      </p>

      <h2>Data Processed</h2>
      <p>
        Member account details, course progress, assessment and proctoring records, batch
        messages, wiki and project content, and content members create, as listed in the Privacy
        Policy.
      </p>

      <h2>Sub-processors</h2>
      <ul>
        {SUBPROCESSORS.map((p) => (
          <li key={p.name}>
            <strong>{p.name}</strong>: {p.purpose}. Data: {p.data}. Location: {p.location}.
          </li>
        ))}
      </ul>

      <h2>Security and Deletion</h2>
      <p>
        Security measures are described on the <Link href={ROUTES.LEGAL_SECURITY}>Security</Link>{" "}
        page. When a member deletes their account, personal data is deleted or anonymized as
        described in the Privacy Policy.
      </p>

      <h2>Requesting a Signed Agreement</h2>
      {email ? (
        <p>
          Organizations that need a signed data processing agreement can write to{" "}
          <a href={`mailto:${email}`}>{email}</a>.
        </p>
      ) : (
        <p>
          A contact for data processing agreements is not configured on this deployment. Raise a
          request through the in-app support ticket system.
        </p>
      )}
    </LegalPage>
  );
}
