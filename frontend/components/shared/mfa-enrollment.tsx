"use client";

import { useEffect, useState, useTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";
import QRCode from "qrcode";
import { toast } from "sonner";

import { MfaRecoveryCodes } from "@/components/shared/mfa-recovery-codes";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import type { ActionResult } from "@/lib/server/api";
import { mfaCodeSchema, type MfaCodeInput } from "@/lib/validation/auth";

interface TotpSetup {
  secret: string;
  uri: string;
}

interface EnrollResult {
  recoveryCodes: string[];
  redirectTo?: string;
}

interface MfaEnrollmentProps {
  begin: () => Promise<ActionResult<TotpSetup>>;
  finish: (code: string) => Promise<ActionResult<EnrollResult>>;
  // Called once the user has seen their recovery codes.
  onComplete: (redirectTo?: string) => void;
  startLabel: string;
  continueLabel: string;
}

// Two-step TOTP enrolment shared by the mandatory sign-in flow and the
// Settings card: start, add the key to an authenticator, confirm a code, save
// recovery codes. Server actions are injected so each caller supplies its own
// authentication (challenge cookie vs. session).
export function MfaEnrollment({ begin, finish, onComplete, startLabel, continueLabel }: MfaEnrollmentProps) {
  const [setup, setSetup] = useState<TotpSetup | null>(null);
  const [result, setResult] = useState<EnrollResult | null>(null);
  const [pending, startTransition] = useTransition();

  const [qr, setQr] = useState<string | null>(null);

  // Rendered in the browser so the secret never leaves this page.
  useEffect(() => {
    if (!setup) return;
    let cancelled = false;
    QRCode.toDataURL(setup.uri, { margin: 1, width: 192 })
      .then((url) => !cancelled && setQr(url))
      .catch(() => !cancelled && setQr(null));
    return () => {
      cancelled = true;
    };
  }, [setup]);

  const form = useForm<MfaCodeInput>({
    resolver: zodResolver(mfaCodeSchema),
    defaultValues: { code: "" },
  });

  function handleBegin() {
    startTransition(async () => {
      const res = await begin();
      if (res.ok && res.data) setSetup(res.data);
      else toast.error(res.error ?? "Couldn't start setup.");
    });
  }

  const handleConfirm = form.handleSubmit(({ code }) => {
    startTransition(async () => {
      const res = await finish(code);
      if (res.ok && res.data) setResult(res.data);
      else toast.error(res.error ?? "Couldn't verify that code.");
    });
  });

  if (result) {
    return (
      <MfaRecoveryCodes
        codes={result.recoveryCodes}
        continueLabel={continueLabel}
        onContinue={() => onComplete(result.redirectTo)}
      />
    );
  }

  if (!setup) {
    return (
      <Button className="touch-target" disabled={pending} type="button" onClick={handleBegin}>
        {pending && <Loader2 aria-hidden className="animate-spin" />}
        {startLabel}
      </Button>
    );
  }

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={handleConfirm}>
        <p className="text-sm text-muted-foreground">
          In your authenticator app (Google Authenticator, 1Password, Authy), add an account
          by scanning this QR code or using the key below, then enter the 6-digit code it shows.
        </p>
        {qr && (
          // eslint-disable-next-line @next/next/no-img-element -- data URL, nothing to optimise
          <img alt="QR code for your authenticator app" className="h-48 w-48 rounded-md border qr-surface p-1" height={192} src={qr} width={192} />
        )}
        <p className="break-all rounded-md border bg-muted px-3 py-2.5 font-mono text-sm" translate="no">
          {setup.secret}
        </p>
        <a className="text-sm font-medium" href={setup.uri}>
          Open in authenticator app
        </a>
        <FormInputField
          autoComplete="one-time-code"
          control={form.control}
          inputMode="numeric"
          label="6-digit code"
          name="code"
          placeholder="123456"
        />
        <Button className="touch-target" disabled={pending} type="submit">
          {pending && <Loader2 aria-hidden className="animate-spin" />}
          Verify and turn on
        </Button>
      </form>
    </Form>
  );
}
