"use client";

import { toast } from "sonner";
import { Copy } from "lucide-react";
import { Button } from "@/components/ui/button";

interface MfaRecoveryCodesProps {
  codes: string[];
  continueLabel: string;
  onContinue: () => void;
}

// One-time display of freshly issued recovery codes. They are stored hashed,
// so this is the only moment they can be copied.
export function MfaRecoveryCodes({ codes, continueLabel, onContinue }: MfaRecoveryCodesProps) {
  async function copy() {
    try {
      await navigator.clipboard.writeText(codes.join("\n"));
      toast.success("Recovery codes copied.");
    } catch {
      toast.error("Couldn't copy. Select the codes and copy them manually.");
    }
  }

  return (
    <div className="form-stack">
      <p className="text-sm text-muted-foreground">
        Save these recovery codes somewhere safe. Each works once if you lose your authenticator.
        They won&apos;t be shown again.
      </p>
      <ul className="grid grid-cols-2 gap-2 rounded-md border bg-muted p-4 font-mono text-sm">
        {codes.map((code) => (
          <li key={code}>{code}</li>
        ))}
      </ul>
      <div className="flex flex-col gap-2 sm:flex-row">
        <Button className="touch-target" type="button" variant="outline" onClick={copy}>
          <Copy aria-hidden className="h-4 w-4" />
          Copy codes
        </Button>
        <Button className="touch-target" type="button" onClick={onContinue}>
          {continueLabel}
        </Button>
      </div>
    </div>
  );
}
