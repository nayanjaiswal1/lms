"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Switch } from "@/components/ui/switch";
import { setAiConsentAction } from "@/app/(app)/settings/privacy/actions";

interface AiConsentCardProps {
  initialConsent: boolean;
}

// Per-user consent for sending diary and capture content to the AI provider
// (DPDP s.6). Off by default; diary AI tools and captures refuse without it.
export function AiConsentCard({ initialConsent }: AiConsentCardProps) {
  const [consent, setConsent] = useState(initialConsent);
  const [pending, startTransition] = useTransition();

  function handleChange(next: boolean) {
    startTransition(async () => {
      const result = await setAiConsentAction(next);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      setConsent(next);
    });
  }

  return (
    <section aria-labelledby="ai-consent-heading" className="card-base p-6 space-y-4">
      <div>
        <h2 className="text-lg font-semibold text-foreground" id="ai-consent-heading">
          AI processing
        </h2>
        <p className="text-sm text-muted-foreground">
          Allow MindForge to send your diary text and uploaded captures (screenshots, PDFs, links) to
          our AI providers to detect habits and tasks, fix grammar and structure notes. Without this,
          those features stay off. You can withdraw at any time.
        </p>
      </div>
      <label className="flex items-center gap-3 text-sm text-foreground">
        <Switch checked={consent} disabled={pending} onCheckedChange={handleChange} />
        {consent ? "AI processing is on" : "AI processing is off"}
      </label>
    </section>
  );
}
