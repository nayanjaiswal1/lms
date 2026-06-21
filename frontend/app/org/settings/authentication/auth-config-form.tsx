"use client";

import { useActionState, useState } from "react";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { OrgAuthConfig } from "@/lib/orgs/types";
import {
  saveAuthConfigAction,
  type AuthConfigActionState,
} from "@/app/org/settings/authentication/actions";

const SSO_PROVIDERS: { value: string; label: string }[] = [
  { value: "google",   label: "Google Workspace" },
  { value: "azure_ad", label: "Microsoft Azure AD" },
  { value: "okta",     label: "Okta" },
  { value: "saml",     label: "SAML 2.0" },
  { value: "oidc",     label: "OpenID Connect" },
];

interface AuthConfigFormProps {
  orgId: string;
  config: OrgAuthConfig;
}

export function AuthConfigForm({ orgId, config }: AuthConfigFormProps) {
  const [ssoEnabled, setSsoEnabled] = useState(config.sso_enabled);
  const [ssoProvider, setSsoProvider] = useState(config.sso_provider ?? "");

  const [state, action, isPending] = useActionState<AuthConfigActionState, FormData>(
    saveAuthConfigAction,
    {},
  );

  return (
    <form action={action} className="space-y-6">
      <input type="hidden" name="org_id" value={orgId} />
      <input type="hidden" name="sso_enabled" value={ssoEnabled ? "true" : "false"} />
      {ssoEnabled && ssoProvider && (
        <input type="hidden" name="sso_provider" value={ssoProvider} />
      )}

      {/* SSO toggle */}
      <div className="flex items-start gap-4">
        <div className="flex-1">
          <Label className="text-sm font-medium text-foreground" htmlFor="sso-toggle">
            Single Sign-On (SSO)
          </Label>
          <p className="text-xs text-muted-foreground mt-0.5">
            Allow members to sign in using your identity provider.
          </p>
        </div>
        <button
          aria-checked={ssoEnabled}
          aria-label="Toggle Single Sign-On"
          className={[
            "relative inline-flex h-5 w-9 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-[--duration-normal] flex-shrink-0 mt-0.5",
            ssoEnabled ? "bg-primary" : "bg-muted",
          ].join(" ")}
          id="sso-toggle"
          onClick={() => setSsoEnabled((v) => !v)}
          role="switch"
          type="button"
        >
          <span
            className={[
              "pointer-events-none inline-block h-4 w-4 rounded-full bg-background shadow-card transition-transform duration-[--duration-normal]",
              ssoEnabled ? "translate-x-4" : "translate-x-0",
            ].join(" ")}
          />
        </button>
      </div>

      {/* Provider select — only when SSO is on */}
      {ssoEnabled && (
        <div className="space-y-1.5 pl-0">
          <Label htmlFor="sso-provider">SSO Provider</Label>
          <Select
            defaultValue={ssoProvider || undefined}
            onValueChange={setSsoProvider}
            required
          >
            <SelectTrigger id="sso-provider" aria-label="Select SSO provider" className="w-full sm:w-64">
              <SelectValue placeholder="Select provider" />
            </SelectTrigger>
            <SelectContent>
              {SSO_PROVIDERS.map((p) => (
                <SelectItem key={p.value} value={p.value}>
                  {p.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      )}

      {/* Allowed domains (read-only reference) */}
      {config.allowed_domains.length > 0 && (
        <div className="space-y-1.5">
          <Label>Allowed Domains</Label>
          <p className="text-xs text-muted-foreground">
            Managed from the{" "}
            <a
              className="text-primary underline-offset-2 hover:underline"
              href="/org/settings/domains"
            >
              Domains
            </a>{" "}
            settings page.
          </p>
          <div className="flex flex-wrap gap-1.5 mt-1">
            {config.allowed_domains.map((d) => (
              <span
                className="inline-flex items-center rounded-md bg-muted px-2 py-0.5 text-xs font-mono text-foreground border border-border"
                key={d}
              >
                {d}
              </span>
            ))}
          </div>
        </div>
      )}

      {state.error && (
        <p className="text-sm text-destructive" role="alert">{state.error}</p>
      )}

      <Button disabled={isPending} type="submit">
        {isPending ? "Saving…" : "Save Changes"}
      </Button>
    </form>
  );
}
