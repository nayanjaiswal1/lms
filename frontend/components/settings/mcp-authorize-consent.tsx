"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import { Bot } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  approveMcpAuthorizeAction,
  denyMcpAuthorizeAction,
  type AuthorizeDecisionInput,
} from "@/app/(app)/settings/integrations/authorize/actions";

interface McpAuthorizeConsentProps {
  clientName: string;
  scopeDescriptions: string[];
  decision: AuthorizeDecisionInput;
}

export function McpAuthorizeConsent({ clientName, scopeDescriptions, decision }: McpAuthorizeConsentProps) {
  const [isPending, startTransition] = useTransition();

  function decide(action: (input: AuthorizeDecisionInput) => Promise<{ ok?: boolean; data?: { redirect_url: string }; error?: string }>) {
    startTransition(async () => {
      const result = await action(decision);
      if (!result.ok || !result.data) {
        toast.error(result.error ?? "Something went wrong.");
        return;
      }
      window.location.href = result.data.redirect_url;
    });
  }

  return (
    <div className="page-container-sm py-10">
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
            {scopeDescriptions.map((desc) => (
              <li className="flex gap-2" key={desc}>
                <span aria-hidden>•</span>
                {desc}
              </li>
            ))}
          </ul>
        </div>

        <p className="text-xs text-muted-foreground">
          You can disconnect {clientName} at any time from Settings → Integrations.
        </p>

        <div className="flex justify-end gap-3">
          <Button disabled={isPending} onClick={() => decide(denyMcpAuthorizeAction)} variant="outline">
            Deny
          </Button>
          <Button disabled={isPending} onClick={() => decide(approveMcpAuthorizeAction)}>
            Approve
          </Button>
        </div>
      </div>
    </div>
  );
}
