import type { Metadata } from "next";

import { AuthPageShell } from "@/components/auth/auth-page-shell";
import { RegisterForm } from "@/components/auth/register-form";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Create an account",
  description: "Create your MindForge account and start learning.",
};

export default function RegisterPage() {
  return (
    <AuthPageShell
      title="Start forging your path"
      description="Create an account and turn what you learn into lasting skill."
      alternatePrompt="Already have an account?"
      alternateLabel="Sign in"
      alternateHref={ROUTES.LOGIN}
    >
      <RegisterForm />
    </AuthPageShell>
  );
}
