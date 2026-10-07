"use client";

import { useActionState, startTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";

import {
  beginMfaEnrollAction,
  finishMfaEnrollAction,
  verifyMfaAction,
  type MfaVerifyState,
} from "@/app/login/mfa/actions";
import { AuthFormError } from "@/components/auth/auth-form-error";
import { MfaEnrollment } from "@/components/shared/mfa-enrollment";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import ROUTES from "@/lib/routes";
import { mfaCodeSchema, type MfaCodeInput } from "@/lib/validation/auth";

const INITIAL_STATE: MfaVerifyState = {};

interface MfaStepFormProps {
  enroll: boolean;
}

export function MfaStepForm({ enroll }: MfaStepFormProps) {
  if (enroll) {
    return (
      <MfaEnrollment
        begin={beginMfaEnrollAction}
        continueLabel="Continue to MindForge"
        finish={finishMfaEnrollAction}
        startLabel="Set up two-factor authentication"
        onComplete={(redirectTo) => window.location.assign(redirectTo ?? ROUTES.HOME)}
      />
    );
  }
  return <VerifyForm />;
}

function VerifyForm() {
  const [state, formAction, isPending] = useActionState(verifyMfaAction, INITIAL_STATE);
  const form = useForm<MfaCodeInput>({
    resolver: zodResolver(mfaCodeSchema),
    defaultValues: { code: "" },
  });

  const onSubmit = form.handleSubmit(({ code }) => {
    const data = new FormData();
    data.set("code", code);
    startTransition(() => formAction(data));
  });

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={onSubmit}>
        <AuthFormError message={state.error} />
        <FormInputField
          autoComplete="one-time-code"
          control={form.control}
          description="Enter the code from your authenticator app, or a recovery code."
          disabled={isPending}
          label="Authentication code"
          name="code"
          placeholder="123456"
        />
        <Button className="mt-1 w-full" disabled={isPending} size="lg" type="submit">
          {isPending ? (
            <>
              <Loader2 aria-hidden className="animate-spin" />
              Verifying…
            </>
          ) : (
            "Verify"
          )}
        </Button>
      </form>
    </Form>
  );
}
