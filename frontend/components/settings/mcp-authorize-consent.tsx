"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Bot } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import {
  approveMcpAuthorizeAction,
  denyMcpAuthorizeAction,
  type AuthorizeDecisionInput,
} from "@/app/(app)/settings/integrations/authorize/actions";

interface McpAuthorizeConsentProps {
  clientName: string;
  redirectHost: string;
  scopes: { key: string; description: string; isNew: boolean }[];
  reapproval: boolean;
  decision: AuthorizeDecisionInput;
}

export function McpAuthorizeConsent({ clientName, redirectHost, scopes, reapproval, decision }: McpAuthorizeConsentProps) {
  const [isPending, startTransition] = useTransition();
  const [granted, setGranted] = useState<Set<string>>(() => new Set(scopes.map((s) => s.key)));
  const hasNewScopes = scopes.some((s) => s.isNew && granted.has(s.key));
  const [confirmedNew, setConfirmedNew] = useState(false);
  const canApprove = granted.size > 0 && (!hasNewScopes || confirmedNew);

  function toggle(key: string, on: boolean) {
    setGranted((prev) => {
      const next = new Set(prev);
      if (on) next.add(key);
      else next.delete(key);
      return next;
    });
  }

  function decide(action: (input: AuthorizeDecisionInput) => Promise<{ ok?: boolean; data?: { redirect_url: string }; error?: string }>) {
    startTransition(async () => {
      const result = await action({
        ...decision,
        granted_scopes: scopes.filter((s) => granted.has(s.key)).map((s) => s.key),
        confirm_new_scopes: confirmedNew,
      });
      if (!result.ok || !result.data) {
        toast.error(result.error ?? "Something went wrong.");
        return;
      }
      window.location.href = result.data.redirect_url;
    });
  }

  return (
    <div className="page-container-sm">
      <div className="card-base p-6 space-y-6">
        <div className="flex items-center gap-3">
          <Bot aria-hidden className="h-10 w-10 text-ai" />
          <div>
            <h1 className="text-lg font-semibold text-foreground">Connect {clientName}?</h1>
            <p className="text-sm text-muted-foreground">This will let {clientName} access your MindForge account.</p>
          </div>
        </div>

        <div className="ai-surface rounded-lg p-4">
          <p className="text-xs font-semibold text-ai mb-2">{clientName} will be able to:</p>
          <ul className="space-y-1.5 text-sm text-foreground">
            {scopes.map((scope) => (
              <li key={scope.key}>
                <label className="flex items-start gap-2">
                  <Checkbox
                    checked={granted.has(scope.key)}
                    className="mt-0.5"
                    disabled={isPending}
                    onCheckedChange={(v) => toggle(scope.key, v === true)}
                  />
                  <span>
                    {scope.description}
                    {reapproval && scope.isNew && (
                      <span className="ml-2 text-xs font-semibold text-warning">New</span>
                    )}
                  </span>
                </label>
              </li>
            ))}
          </ul>
        </div>

        {hasNewScopes && (
          <label className="flex items-start gap-2 text-sm text-foreground">
            <Checkbox
              checked={confirmedNew}
              className="mt-0.5"
              disabled={isPending}
              onCheckedChange={(v) => setConfirmedNew(v === true)}
            />
            <span>
              {clientName} is asking for permissions it did not have before. I understand and want to grant the
              ones marked New.
            </span>
          </label>
        )}

        <p className="text-xs text-muted-foreground break-all">
          After you approve, you will be sent to <span className="font-medium text-foreground">{redirectHost}</span>.
          Only continue if you recognise it.
        </p>

        <p className="text-xs text-muted-foreground">
          You can disconnect {clientName} at any time from Settings → Integrations.
        </p>

        <div className="flex justify-end gap-3">
          <Button disabled={isPending} variant="outline" onClick={() => decide(denyMcpAuthorizeAction)}>
            Deny
          </Button>
          <Button disabled={isPending || !canApprove} onClick={() => decide(approveMcpAuthorizeAction)}>
            Approve
          </Button>
        </div>
      </div>
    </div>
  );
}
