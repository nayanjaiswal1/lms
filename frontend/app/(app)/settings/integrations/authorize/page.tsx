import { apiGet } from "@/lib/server/api";
import { McpAuthorizeConsent } from "@/components/settings/mcp-authorize-consent";

interface AuthorizeDetails {
  client_name: string;
  redirect_host: string;
  scopes: string[];
  scope_keys: string[];
  new_scopes: string[];
  reapproval: boolean;
  scope_descriptions: string[];
}

interface SettingsIntegrationsAuthorizePageProps {
  searchParams: Promise<{
    client_id?: string;
    redirect_uri?: string;
    scope?: string;
    state?: string;
    code_challenge?: string;
  }>;
}

export default async function SettingsIntegrationsAuthorizePage({
  searchParams,
}: SettingsIntegrationsAuthorizePageProps) {
  const params = await searchParams;
  const clientId = params.client_id ?? "";
  const redirectUri = params.redirect_uri ?? "";
  const scope = params.scope ?? "";
  const state = params.state ?? "";
  const codeChallenge = params.code_challenge ?? "";

  const query = new URLSearchParams({ client_id: clientId, redirect_uri: redirectUri, scope }).toString();
  const details = await apiGet<AuthorizeDetails>(`/oauth/authorize/details?${query}`);

  return (
    <McpAuthorizeConsent
      clientName={details.client_name}
      redirectHost={details.redirect_host}
      decision={{
        client_id: clientId,
        redirect_uri: redirectUri,
        scope: details.scopes.join(" "),
        state,
        code_challenge: codeChallenge,
      }}
      scopes={details.scope_keys.map((key, i) => ({
        key,
        description: details.scope_descriptions[i],
        isNew: details.new_scopes.includes(key),
      }))}
      reapproval={details.reapproval}
    />
  );
}
