import type { Metadata } from "next";

import { LegalPage } from "@/components/legal/legal-page";
import { securityContactEmail } from "@/lib/legal-constants";

export const metadata: Metadata = {
  title: "Security",
  description: "How MindForge protects accounts and how to report a vulnerability.",
};

export default function SecurityPage() {
  const email = securityContactEmail();
  return (
    <LegalPage title="Security">
      <h2>How We Protect Your Account</h2>
      <ul>
        <li>Passwords are stored as bcrypt hashes.</li>
        <li>
          Sessions use short-lived access tokens and rotating refresh tokens in HttpOnly cookies.
        </li>
        <li>State-changing requests are protected with a CSRF token.</li>
        <li>
          Repeated failed sign-ins on an account trigger a temporary lockout that lengthens with
          further failures.
        </li>
        <li>Passkey (WebAuthn) sign-in is available under Settings → Security.</li>
        <li>We email you when your password is reset or a passkey is added or removed.</li>
        <li>
          AI Connector connections can be revoked at any time, and replaying a rotated-out
          connector refresh token revokes the connection.
        </li>
        <li>Lab code runs in sandboxed containers separate from the application.</li>
      </ul>

      <h2>Reporting a Vulnerability</h2>
      {email ? (
        <p>
          Email <a href={`mailto:${email}`}>{email}</a> with a description and steps to reproduce.
          Please do not access data that is not yours, and give us reasonable time to fix the issue
          before disclosing it.
        </p>
      ) : (
        <p>
          A security contact is not configured on this deployment. Report vulnerabilities through
          the in-app support ticket system.
        </p>
      )}
    </LegalPage>
  );
}
