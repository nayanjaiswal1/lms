import type { Metadata } from "next";
import Link from "next/link";
import { MailOpen } from "lucide-react";

import { AuthPageShell } from "@/components/auth/auth-page-shell";
import { VerifyEmailForm } from "@/app/verify-email/verify-form";
import { VerifyEmailAutoSubmit } from "@/app/verify-email/auto-submit";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Verify your email",
  description: "Check your inbox and enter your verification code.",
};

interface VerifyEmailPageProps {
  searchParams: Promise<{ email?: string; token?: string }>;
}

export default async function VerifyEmailPage({ searchParams }: VerifyEmailPageProps) {
  const params = await searchParams;
  const email = params.email ?? "";
  const token = params.token;

  const description = email
    ? `We sent a verification link to ${email}. Enter the code below to activate your account.`
    : "Enter the verification code we sent to your email address.";

  return (
    <AuthPageShell
      title="Verify your email"
      description={description}
      alternatePrompt="Already verified?"
      alternateLabel="Sign in"
      alternateHref={ROUTES.LOGIN}
    >
      <div className="flex flex-col gap-6">
        <div className="flex items-center gap-3 rounded-lg border border-border bg-muted p-4">
          <MailOpen aria-hidden className="h-5 w-5 shrink-0 text-primary" />
          <p className="text-sm text-muted-foreground">
            Check your spam folder if you don&apos;t see the email within a minute.
          </p>
        </div>

        {token ? (
          <VerifyEmailAutoSubmit token={token} email={email} />
        ) : (
          <VerifyEmailForm />
        )}

        <p className="text-center text-sm text-muted-foreground sm:text-left">
          Didn&apos;t receive it?{" "}
          <Link
            href={`${ROUTES.REGISTER}`}
            className="font-medium"
          >
            Resend verification
          </Link>
        </p>
      </div>
    </AuthPageShell>
  );
}
