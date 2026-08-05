import type { Metadata } from "next";
import Link from "next/link";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { CheckCircle2 } from "lucide-react";

import { AuthPageShell } from "@/components/auth/auth-page-shell";
import { LoginForm } from "@/components/auth/login-form";
import { IconMessage } from "@/components/shared/icon-message";
import ROUTES from "@/lib/routes";
import { safeNextPath } from "@/lib/utils";

export const metadata: Metadata = {
  title: "Sign in",
  description: "Sign in to your MindForge account to continue learning.",
};

interface LoginPageProps {
  searchParams: Promise<{ verified?: string; reset?: string; error?: string; next?: string }>;
}

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;

  const cookieStore = await cookies();
  if (cookieStore.get("access_token")?.value) {
    redirect(safeNextPath(params.next) ?? ROUTES.DASHBOARD);
  }

  const verified = params.verified === "1";
  const reset = params.reset === "1";

  return (
    <AuthPageShell
      alternateHref={ROUTES.REGISTER}
      alternateLabel="Create an account"
      alternatePrompt="New to MindForge?"
      description="Sign in to continue forging your knowledge."
      title="Welcome back"
    >
      {verified && (
        <IconMessage icon={CheckCircle2} tone="success">
          Email verified! Sign in to continue.
        </IconMessage>
      )}
      {reset && (
        <IconMessage icon={CheckCircle2} tone="success">
          Password updated! Sign in with your new password.
        </IconMessage>
      )}
      <LoginForm next={params.next} oauthError={params.error} />
      <p className="text-center text-sm text-muted-foreground sm:text-left">
        Just exploring?{" "}
        <Link className="font-medium" href={ROUTES.DEMO}>
          Try demo →
        </Link>
      </p>
    </AuthPageShell>
  );
}
