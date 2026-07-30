"use client";

import { useActionState, startTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2, MailCheck } from "lucide-react";

import { forgotPasswordAction, type ForgotPasswordState } from "@/app/forgot-password/actions";
import { AuthFormError } from "@/components/auth/auth-form-error";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { forgotPasswordSchema, type ForgotPasswordInput, AUTH_COPY } from "@/lib/validation/auth";

const INITIAL_STATE: ForgotPasswordState = {};

export function ForgotPasswordForm() {
  const [state, formAction, isPending] = useActionState(forgotPasswordAction, INITIAL_STATE);

  const form = useForm<ForgotPasswordInput>({
    resolver: zodResolver(forgotPasswordSchema),
    defaultValues: { email: "" },
    mode: "onTouched",
  });

  const onSubmit = form.handleSubmit((values) => {
    const data = new FormData();
    data.set("email", values.email);
    startTransition(() => formAction(data));
  });

  if (state.sent) {
    return (
      <div
        className="flex items-start gap-3 rounded-lg border border-border bg-muted p-4"
        role="status"
      >
        <MailCheck aria-hidden className="mt-0.5 h-5 w-5 shrink-0 text-primary" />
        <p className="text-sm text-muted-foreground">{AUTH_COPY.resetLinkSent}</p>
      </div>
    );
  }

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={onSubmit}>
        <AuthFormError message={state.error} />

        <FormInputField
          autoComplete="email"
          control={form.control}
          disabled={isPending}
          inputMode="email"
          label="Email"
          name="email"
          placeholder="you@example.com"
          serverError={state.fieldErrors?.email}
          type="email"
        />

        <Button className="w-full" disabled={isPending} size="lg" type="submit">
          {isPending ? (
            <>
              <Loader2 aria-hidden className="animate-spin" />
              Sending…
            </>
          ) : (
            "Send reset link"
          )}
        </Button>
      </form>
    </Form>
  );
}
