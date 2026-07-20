import { apiGet } from "@/lib/server/api";
import { PasskeyManager, type PasskeyCredential } from "@/components/settings/passkey-manager";

export default async function SettingsSecurityPage() {
  const { credentials } = await apiGet<{ credentials: PasskeyCredential[] }>(
    "/api/auth/webauthn/credentials",
  );

  return (
    <div className="space-y-6">
      <PasskeyManager credentials={credentials} />
    </div>
  );
}
