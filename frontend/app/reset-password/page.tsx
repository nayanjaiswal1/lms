import type { Metadata } from "next";
import Link from "next/link";
import { AlertTriangle } from "lucide-react";

import { AuthPageShell } from "@/components/auth/auth-page-shell";
import { ResetPasswordForm } from "@/app/reset-password/reset-password-form";
import { AUTH_COPY } from "@/lib/validation/auth";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Reset password",
  description: "Choose a new password for your MindForge account.",
};

interface ResetPasswordPageProps {
  searchParams: Promise<{ token?: string }>;
}

export default async function ResetPasswordPage({ searchParams }: ResetPasswordPageProps) {
  const { token } = await searchParams;

  return (
    <AuthPageShell
      alternateHref={ROUTES.LOGIN}
      alternateLabel="Sign in"
      alternatePrompt="Remembered it?"
      description="Choose a new password for your account."
      title="Reset your password"
    >
      {token ? (
        <ResetPasswordForm token={token} />
      ) : (
        <div
          className="flex items-start gap-3 rounded-lg border border-destructive/25 bg-destructive/10 p-4"
          role="alert"
        >
          <AlertTriangle aria-hidden className="mt-0.5 h-5 w-5 shrink-0 text-destructive" />
          <p className="text-sm text-destructive">
            {AUTH_COPY.invalidResetToken}{" "}
            <Link className="font-medium underline underline-offset-2" href={ROUTES.FORGOT_PASSWORD}>
              Request a new one
            </Link>
            .
          </p>
        </div>
      )}
    </AuthPageShell>
  );
}
