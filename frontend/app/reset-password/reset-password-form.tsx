"use client";

import { useActionState, startTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";

import { resetPasswordAction, type ResetPasswordState } from "@/app/reset-password/actions";
import { AuthFormError } from "@/components/auth/auth-form-error";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { resetPasswordSchema, type ResetPasswordInput } from "@/lib/validation/auth";

const INITIAL_STATE: ResetPasswordState = {};

interface ResetPasswordFormProps {
  token: string;
}

export function ResetPasswordForm({ token }: ResetPasswordFormProps) {
  const [state, formAction, isPending] = useActionState(resetPasswordAction, INITIAL_STATE);

  const form = useForm<ResetPasswordInput>({
    resolver: zodResolver(resetPasswordSchema),
    defaultValues: { newPassword: "", confirmPassword: "" },
    mode: "onTouched",
  });

  const onSubmit = form.handleSubmit((values) => {
    const data = new FormData();
    data.set("token", token);
    data.set("newPassword", values.newPassword);
    data.set("confirmPassword", values.confirmPassword);
    startTransition(() => formAction(data));
  });

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={onSubmit}>
        <AuthFormError message={state.error} />

        <FormInputField
          autoComplete="new-password"
          control={form.control}
          description="8–72 characters"
          disabled={isPending}
          label="New password"
          name="newPassword"
          placeholder="Create a new password"
          serverError={state.fieldErrors?.newPassword}
          type="password"
        />

        <FormInputField
          autoComplete="new-password"
          control={form.control}
          disabled={isPending}
          label="Confirm password"
          name="confirmPassword"
          placeholder="Enter it again"
          serverError={state.fieldErrors?.confirmPassword}
          type="password"
        />

        <Button className="w-full" disabled={isPending} size="lg" type="submit">
          {isPending ? (
            <>
              <Loader2 aria-hidden className="animate-spin" />
              Updating…
            </>
          ) : (
            "Reset password"
          )}
        </Button>
      </form>
    </Form>
  );
}
