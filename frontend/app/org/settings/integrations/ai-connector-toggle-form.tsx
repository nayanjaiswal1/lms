"use client";

import { useActionState, useState } from "react";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import type { OrgAIConnectorConfig } from "@/lib/orgs/types";
import {
  saveAIConnectorConfigAction,
  type AIConnectorConfigActionState,
} from "@/app/org/settings/integrations/actions";

interface AIConnectorToggleFormProps {
  orgId: string;
  config: OrgAIConnectorConfig;
}

export function AIConnectorToggleForm({ orgId, config }: AIConnectorToggleFormProps) {
  const [enabled, setEnabled] = useState(config.enabled);

  const [state, action, isPending] = useActionState<AIConnectorConfigActionState, FormData>(
    saveAIConnectorConfigAction,
    {},
  );

  return (
    <form action={action} className="space-y-4">
      <input name="org_id" type="hidden" value={orgId} />
      <input name="enabled" type="hidden" value={enabled ? "true" : "false"} />

      <div className="flex items-start gap-4">
        <div className="flex-1">
          <Label className="text-sm font-medium text-foreground" htmlFor="ai-connector-toggle">
            AI Connector
          </Label>
          <p className="text-xs text-muted-foreground mt-0.5">
            Let members connect their own Claude or ChatGPT to MindForge via
            MCP — reads lessons, saves notes, and manages their calendar.
            Nothing is connected until a member opts in individually.
          </p>
        </div>
        <button
          aria-checked={enabled}
          aria-label="Toggle AI Connector"
          className={[
            "relative inline-flex h-5 w-9 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-[--duration-normal] flex-shrink-0 mt-0.5",
            enabled ? "bg-primary" : "bg-muted",
          ].join(" ")}
          id="ai-connector-toggle"
          role="switch"
          type="button"
          onClick={() => setEnabled((v) => !v)}
        >
          <span
            className={[
              "pointer-events-none inline-block h-4 w-4 rounded-full bg-background shadow-card transition-transform duration-[--duration-normal]",
              enabled ? "translate-x-4" : "translate-x-0",
            ].join(" ")}
          />
        </button>
      </div>

      {state.error && (
        <p className="text-sm text-destructive" role="alert">{state.error}</p>
      )}

      <Button disabled={isPending} type="submit">
        {isPending ? "Saving…" : "Save Changes"}
      </Button>
    </form>
  );
}
