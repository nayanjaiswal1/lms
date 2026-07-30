import type { Metadata } from "next";

import { AuthPageShell } from "@/components/auth/auth-page-shell";
import { ForgotPasswordForm } from "@/app/forgot-password/forgot-password-form";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Forgot password",
  description: "Reset your MindForge account password.",
};

export default function ForgotPasswordPage() {
  return (
    <AuthPageShell
      alternateHref={ROUTES.LOGIN}
      alternateLabel="Sign in"
      alternatePrompt="Remembered it?"
      description="Enter your email and we'll send you a link to reset it."
      title="Forgot your password?"
    >
      <ForgotPasswordForm />
    </AuthPageShell>
  );
}
