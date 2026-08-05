"use client";

import { useState } from "react";
import Link from "next/link";
import { X, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { AccessGate } from "@/components/shared/access-gate";
import { IconMessage } from "@/components/shared/icon-message";
import { FEATURES } from "@/lib/features";
import ROUTES from "@/lib/routes";

interface AIConnectorNudgeProps {
  hasConnection: boolean;
}

// A nudge pointing students who've never connected an AI toward Settings →
// Integrations. Only relevant when the org has the AI Connector feature on
// (AccessGate) and the student hasn't connected one yet. Dismissal is
// per-render only (no persistence) — it naturally stops showing the moment
// the student actually connects, which is the state that matters; a
// localStorage-backed "never show again" would need a client-only read that
// mismatches server-rendered HTML on first paint, not worth it for a nudge.
export function AIConnectorNudge({ hasConnection }: AIConnectorNudgeProps) {
  const [dismissed, setDismissed] = useState(false);

  if (hasConnection || dismissed) return null;

  return (
    <AccessGate feature={FEATURES.AI_CONNECTOR} mode="hide">
      <IconMessage
        action={
          <div className="flex items-center gap-2">
            <Button asChild size="sm" variant="outline">
              <Link href={ROUTES.SETTINGS_INTEGRATIONS}>Connect</Link>
            </Button>
            <Button aria-label="Dismiss" size="icon" variant="ghost" onClick={() => setDismissed(true)}>
              <X aria-hidden className="h-4 w-4" />
            </Button>
          </div>
        }
        className="ai-surface mb-6 gap-3 p-4 text-foreground"
        icon={Sparkles}
        size="md"
        tone="ai"
        variant="plain"
      >
        Connect your own Claude or ChatGPT to MindForge — it can read your lessons, save notes,
        and manage your calendar for you.
      </IconMessage>
    </AccessGate>
  );
}
