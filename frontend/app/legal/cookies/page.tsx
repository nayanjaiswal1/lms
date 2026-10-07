import type { Metadata } from "next";

import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Cookie Policy",
  description: "The cookies MindForge sets and why.",
};

export default function CookiesPage() {
  return (
    <LegalPage title="Cookie Policy">
      <p>
        MindForge sets only the cookies needed to sign you in and protect your session. We do not
        set advertising cookies.
      </p>

      <h2>Cookies We Set</h2>
      <ul>
        <li>
          <strong>access_token</strong>: short-lived sign-in token. HttpOnly, SameSite=Lax. Expires
          when the access token does.
        </li>
        <li>
          <strong>refresh_token</strong>: lets us renew your session without asking you to sign in
          again. HttpOnly, SameSite=Lax. Valid for the refresh-token lifetime.
        </li>
        <li>
          <strong>csrf_token</strong>: readable by the page so it can be sent back with
          state-changing requests, protecting against cross-site request forgery. SameSite=Lax.
        </li>
      </ul>

      <h2>Local Storage</h2>
      <p>
        The app may keep interface preferences and unsent drafts in your browser&apos;s local
        storage. These stay on your device.
      </p>

      <h2>Controlling Cookies</h2>
      <p>
        You can block or delete cookies in your browser settings, but you will not be able to stay
        signed in without the cookies above. Signing out clears them.
      </p>
    </LegalPage>
  );
}
