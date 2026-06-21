import type { Metadata } from "next";
import Link from "next/link";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { CheckCircle2 } from "lucide-react";

import { AuthPageShell } from "@/components/auth/auth-page-shell";
import { LoginForm } from "@/components/auth/login-form";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Sign in",
  description: "Sign in to your MindForge account to continue learning.",
};

interface LoginPageProps {
  searchParams: Promise<{ verified?: string; error?: string }>;
}

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const cookieStore = await cookies();
  if (cookieStore.get("access_token")?.value) {
    redirect(ROUTES.DASHBOARD);
  }

  const params = await searchParams;
  const verified = params.verified === "1";

  return (
    <AuthPageShell
      title="Welcome back"
      description="Sign in to continue forging your knowledge."
      alternatePrompt="New to MindForge?"
      alternateLabel="Create an account"
      alternateHref={ROUTES.REGISTER}
    >
      {verified && (
        <p className="flex items-center gap-2 rounded-md border border-border bg-muted px-3 py-2.5 text-sm text-foreground">
          <CheckCircle2 aria-hidden className="h-4 w-4 shrink-0 text-primary" />
          Email verified! Sign in to continue.
        </p>
      )}
      <LoginForm oauthError={params.error} />
      <p className="text-center text-sm text-muted-foreground sm:text-left">
        Just exploring?{" "}
        <Link href={ROUTES.DEMO} className="font-medium">
          Try demo →
        </Link>
      </p>
    </AuthPageShell>
  );
}
