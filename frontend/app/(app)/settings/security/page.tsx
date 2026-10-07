import { apiGet } from "@/lib/server/api";
import { ChangePasswordCard } from "@/components/settings/change-password-card";
import { MfaCard, type MfaStatus } from "@/components/settings/mfa-card";
import { PasskeyManager, type PasskeyCredential } from "@/components/settings/passkey-manager";

export default async function SettingsSecurityPage() {
  const [{ credentials }, mfa] = await Promise.all([
    apiGet<{ credentials: PasskeyCredential[] }>("/api/auth/webauthn/credentials"),
    apiGet<MfaStatus>("/api/auth/mfa"),
  ]);

  return (
    <div className="space-y-6">
      <ChangePasswordCard />
      <MfaCard status={mfa} />
      <PasskeyManager credentials={credentials} />
    </div>
  );
}
