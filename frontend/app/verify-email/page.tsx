import type { Metadata } from "next";
import Link from "next/link";
import { MailOpen } from "lucide-react";

import { AuthPageShell } from "@/components/auth/auth-page-shell";
import { VerifyEmailForm } from "@/app/verify-email/verify-form";
import { VerifyEmailAutoSubmit } from "@/app/verify-email/auto-submit";
import { IconMessage } from "@/components/shared/icon-message";
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
      alternateHref={ROUTES.LOGIN}
      alternateLabel="Sign in"
      alternatePrompt="Already verified?"
      description={description}
      title="Verify your email"
    >
      <div className="flex flex-col gap-6">
        <IconMessage
          className="rounded-lg border border-border bg-muted p-4 text-muted-foreground"
          icon={MailOpen}
          iconClassName="text-primary"
          size="md"
          variant="plain"
        >
          Check your spam folder if you don&apos;t see the email within a minute.
        </IconMessage>

        {token ? (
          <VerifyEmailAutoSubmit email={email} token={token} />
        ) : (
          <VerifyEmailForm />
        )}

        <p className="text-center text-sm text-muted-foreground sm:text-left">
          Didn&apos;t receive it?{" "}
          <Link
            className="font-medium"
            href={`${ROUTES.REGISTER}`}
          >
            Resend verification
          </Link>
        </p>
      </div>
    </AuthPageShell>
  );
}
