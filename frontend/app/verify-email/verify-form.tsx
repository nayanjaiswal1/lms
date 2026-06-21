"use client";

import { useActionState } from "react";
import { Loader2 } from "lucide-react";

import { verifyEmailAction, type VerifyEmailState } from "@/app/verify-email/actions";
import { AuthFormError } from "@/components/auth/auth-form-error";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const INITIAL_STATE: VerifyEmailState = {};

export function VerifyEmailForm() {
  const [state, formAction, isPending] = useActionState(verifyEmailAction, INITIAL_STATE);

  return (
    <form className="form-stack" action={formAction}>
      <AuthFormError message={state.error} />

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="token">Verification code</Label>
        <Input
          id="token"
          name="token"
          type="text"
          inputMode="numeric"
          autoComplete="one-time-code"
          placeholder="Enter the code from your email"
          disabled={isPending}
          className="font-mono tracking-widest"
        />
      </div>

      <Button type="submit" size="lg" disabled={isPending} className="w-full">
        {isPending ? (
          <>
            <Loader2 aria-hidden className="animate-spin" />
            Verifying…
          </>
        ) : (
          "Verify email"
        )}
      </Button>
    </form>
  );
}
