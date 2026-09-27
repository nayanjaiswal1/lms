import { redirect } from "next/navigation";
import { PrivacySettings } from "@/components/settings/privacy-settings";
import { ProfileVisibilityForm } from "@/components/profile/profile-visibility-form";
import { fetchMyProfile } from "@/lib/profile/server";
import ROUTES from "@/lib/routes";

export default async function SettingsPrivacyPage() {
  const profile = await fetchMyProfile();
  if (!profile) redirect(ROUTES.LOGIN);

  return (
    <div className="space-y-6">
      <ProfileVisibilityForm profile={profile} />
      <PrivacySettings />
    </div>
  );
}
