"use client";

import { useRef, useEffect, useActionState } from "react";
import { Loader2 } from "lucide-react";

import { verifyEmailAction, type VerifyEmailState } from "@/app/verify-email/actions";
import { AuthFormError } from "@/components/auth/auth-form-error";

interface VerifyEmailAutoSubmitProps {
  token: string;
  email: string;
}

const INITIAL_STATE: VerifyEmailState = {};

export function VerifyEmailAutoSubmit({ token, email }: VerifyEmailAutoSubmitProps) {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, isPending] = useActionState(verifyEmailAction, INITIAL_STATE);

  // One-time DOM interaction on mount — the only valid useEffect in this codebase.
  // We auto-submit because the token arrives via URL from the email link and the
  // user doesn't need to copy-paste anything; the verification should be seamless.
  useEffect(() => {
    formRef.current?.requestSubmit();
  }, []);

  return (
    <div className="flex flex-col gap-4">
      {isPending && (
        <p className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 aria-hidden className="h-4 w-4 animate-spin" />
          Verifying your email for <span className="font-medium text-foreground">{email}</span>…
        </p>
      )}

      <AuthFormError message={state.error} />

      <form ref={formRef} action={formAction} className="hidden" aria-hidden>
        <input type="hidden" name="token" value={token} />
      </form>
    </div>
  );
}
