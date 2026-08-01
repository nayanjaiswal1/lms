import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { OnboardingWizard } from "@/app/onboarding/onboarding-wizard";
import { getAuthMe } from "@/lib/server/auth";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Set up your profile",
  description: "Personalise MindForge to match your learning goals.",
};

export default async function OnboardingPage() {
  const me = await getAuthMe();
  if (me?.onboarding_completed) redirect(ROUTES.DASHBOARD);

  return <OnboardingWizard />;
}
