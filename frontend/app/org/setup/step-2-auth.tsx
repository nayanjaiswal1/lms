"use client";

import { useActionState, startTransition, useState } from "react";
import { ArrowLeft, ArrowRight, Loader2 } from "lucide-react";
import Link from "next/link";

import { saveStep2Action, type SaveStepState } from "@/app/org/setup/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import ROUTES from "@/lib/routes";
import type { OrgAuthConfig } from "@/lib/orgs/types";

const INITIAL_STATE: SaveStepState = {};

interface Step2AuthProps {
  orgId: string;
  authConfig: OrgAuthConfig | null;
}

export function Step2Auth({ orgId, authConfig }: Step2AuthProps) {
  const [state, formAction, isPending] = useActionState(
    saveStep2Action,
    INITIAL_STATE,
  );

  const [ssoEnabled, setSsoEnabled] = useState(
    authConfig?.sso_enabled ?? false,
  );
  const [domainInput, setDomainInput] = useState(
    (authConfig?.allowed_domains ?? []).join(", "),
  );

  const onSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const data = new FormData();
    data.set("org_id", orgId);
    data.set("allowed_domains", domainInput);
    data.set("sso_enabled", String(ssoEnabled));
    startTransition(() => formAction(data));
  };

  return (
    <form noValidate className="form-stack" onSubmit={onSubmit}>
      <div className="mb-2">
        <h2 className="section-title">Authentication</h2>
        <p className="text-sm text-muted-foreground">
          Configure who can join and how members sign in.
        </p>
      </div>

      {state.error && (
        <p role="alert" className="rounded-md border border-border bg-muted px-3 py-2.5 text-sm text-destructive">
          {state.error}
        </p>
      )}

      {/* Allowed email domains */}
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="allowed_domains">Allowed email domains</Label>
        <Input
          id="allowed_domains"
          value={domainInput}
          onChange={(e) => setDomainInput(e.target.value)}
          placeholder="example.com, company.org"
          disabled={isPending}
        />
        <p className="text-xs text-muted-foreground">
          Comma-separated. Only users with these email domains can join. Leave blank to allow any email.
        </p>
        {state.fieldErrors?.allowed_domains && (
          <p className="text-sm text-destructive">{state.fieldErrors.allowed_domains}</p>
        )}
      </div>

      {/* SSO toggle */}
      <div className="flex items-start gap-3 rounded-lg border border-border p-4">
        <Checkbox
          id="sso_enabled"
          checked={ssoEnabled}
          onCheckedChange={(checked) => setSsoEnabled(checked === true)}
          disabled={isPending}
          className="mt-0.5"
        />
        <div className="flex flex-col gap-0.5">
          <Label htmlFor="sso_enabled" className="cursor-pointer font-medium">
            Enable Single Sign-On (SSO)
          </Label>
          <p className="text-xs text-muted-foreground">
            Require members to authenticate via your identity provider. SSO
            provider details can be configured in{" "}
            <Link href={ROUTES.ORG_SETTINGS_AUTH} className="underline underline-offset-4">
              authentication settings
            </Link>{" "}
            after setup.
          </p>
        </div>
      </div>

      <div className="flex items-center justify-between pt-2">
        <Button
          type="button"
          variant="outline"
          disabled={isPending}
          className="gap-2"
          asChild
        >
          <Link href={`${ROUTES.ORG_SETUP}?step=1`}>
            <ArrowLeft aria-hidden className="h-4 w-4" />
            Back
          </Link>
        </Button>

        <Button type="submit" disabled={isPending} className="gap-2">
          {isPending ? (
            <>
              <Loader2 aria-hidden className="animate-spin" />
              Saving…
            </>
          ) : (
            <>
              Next <ArrowRight aria-hidden className="h-4 w-4" />
            </>
          )}
        </Button>
      </div>
    </form>
  );
}
