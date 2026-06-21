import type { Metadata } from "next";

import { OnboardingWizard } from "@/app/onboarding/onboarding-wizard";

export const metadata: Metadata = {
  title: "Set up your profile",
  description: "Personalise MindForge to match your learning goals.",
};

export default function OnboardingPage() {
  return <OnboardingWizard />;
}
