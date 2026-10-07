import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { AuthPageShell } from "@/components/auth/auth-page-shell";
import { MfaStepForm } from "@/components/auth/mfa-step-form";
import { readMfaChallenge } from "@/lib/server/mfa-challenge";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Two-factor authentication",
  description: "Confirm it's you to finish signing in to MindForge.",
};

export default async function LoginMfaPage() {
  const challenge = await readMfaChallenge();
  if (!challenge) redirect(ROUTES.LOGIN);

  return (
    <AuthPageShell
      alternateHref={ROUTES.LOGIN}
      alternateLabel="Back to sign in"
      alternatePrompt="Wrong account?"
      description={
        challenge.enroll
          ? "Your role requires two-factor authentication. Set it up to continue."
          : "Enter the code from your authenticator app to finish signing in."
      }
      title={challenge.enroll ? "Set up two-factor authentication" : "Two-factor authentication"}
    >
      <MfaStepForm enroll={challenge.enroll} />
    </AuthPageShell>
  );
}
