import { redirect } from "next/navigation";
import { AiConsentCard } from "@/components/settings/ai-consent-card";
import { NomineeCard } from "@/components/settings/nominee-card";
import { PrivacySettings } from "@/components/settings/privacy-settings";
import { ProfileVisibilityForm } from "@/components/profile/profile-visibility-form";
import { fetchMyProfile } from "@/lib/profile/server";
import ROUTES from "@/lib/routes";
import { apiGet } from "@/lib/server/api";
import type { PrivacySettingsData } from "./actions";

export default async function SettingsPrivacyPage() {
  const [profile, settings] = await Promise.all([
    fetchMyProfile(),
    apiGet<PrivacySettingsData>("/api/privacy/settings"),
  ]);
  if (!profile) redirect(ROUTES.LOGIN);

  return (
    <div className="space-y-6">
      <ProfileVisibilityForm profile={profile} />
      <AiConsentCard initialConsent={settings.ai_consent} />
      <NomineeCard nominee={settings.nominee} />
      <PrivacySettings />
    </div>
  );
}
