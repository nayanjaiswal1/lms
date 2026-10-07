"use client";

import { useState, useTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";
import { toast } from "sonner";

import { regenerateRecoveryCodesAction } from "@/app/(app)/settings/security/actions";
import { MfaRecoveryCodes } from "@/components/shared/mfa-recovery-codes";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { mfaCodeSchema, type MfaCodeInput } from "@/lib/validation/auth";

interface MfaRecoveryRegenerateProps {
  onDone: () => void;
}

// Issues a fresh recovery-code set (old ones stop working). The new codes are
// shown once, here, and dropped from state when the user continues.
export function MfaRecoveryRegenerate({ onDone }: MfaRecoveryRegenerateProps) {
  const [pending, startTransition] = useTransition();
  const [codes, setCodes] = useState<string[] | null>(null);
  const form = useForm<MfaCodeInput>({
    resolver: zodResolver(mfaCodeSchema),
    defaultValues: { code: "" },
  });

  const onSubmit = form.handleSubmit(({ code }) => {
    startTransition(async () => {
      const res = await regenerateRecoveryCodesAction(code);
      if (res.ok && res.data) {
        form.reset();
        setCodes(res.data.recoveryCodes);
      } else {
        toast.error(res.error ?? "Couldn't generate new recovery codes.");
      }
    });
  });

  if (codes) {
    return (
      <MfaRecoveryCodes
        codes={codes}
        continueLabel="Done"
        onContinue={() => {
          setCodes(null);
          onDone();
        }}
      />
    );
  }

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={onSubmit}>
        <FormInputField
          autoComplete="one-time-code"
          control={form.control}
          description="Enter a code from your authenticator app to replace your recovery codes. The old ones stop working."
          disabled={pending}
          inputMode="numeric"
          label="Authenticator code"
          name="code"
        />
        <Button className="touch-target self-start" disabled={pending} type="submit" variant="outline">
          {pending && <Loader2 aria-hidden className="animate-spin" />}
          Generate new recovery codes
        </Button>
      </form>
    </Form>
  );
}
