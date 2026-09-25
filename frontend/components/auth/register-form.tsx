"use client";

import Link from "next/link";
import { useActionState, startTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";

import { registerAction, type RegisterState } from "@/app/register/actions";
import { AuthFormError } from "@/components/auth/auth-form-error";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormCheckboxField } from "@/components/ui/form-checkbox-field";
import ROUTES from "@/lib/routes";
import { registerSchema, type RegisterInput } from "@/lib/validation/auth";

const INITIAL_STATE: RegisterState = {};

export function RegisterForm() {
  const [state, formAction, isPending] = useActionState(
    registerAction,
    INITIAL_STATE,
  );

  const form = useForm<RegisterInput>({
    resolver: zodResolver(registerSchema),
    defaultValues: {
      name: "",
      email: "",
      password: "",
      confirmPassword: "",
      acceptTerms: false,
    },
    mode: "onTouched",
  });

  const onSubmit = form.handleSubmit((values) => {
    const data = new FormData();
    data.set("name", values.name);
    data.set("email", values.email);
    data.set("password", values.password);
    data.set("confirmPassword", values.confirmPassword);
    data.set("acceptTerms", String(values.acceptTerms));
    startTransition(() => formAction(data));
  });

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={onSubmit}>
        <AuthFormError message={state.error} />

        <FormInputField
          autoComplete="name"
          control={form.control}
          disabled={isPending}
          label="Full name"
          name="name"
          placeholder="Alex Morgan"
          serverError={state.fieldErrors?.name}
        />

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

        <FormInputField
          autoComplete="new-password"
          control={form.control}
          description="8–72 characters"
          disabled={isPending}
          label="Password"
          name="password"
          placeholder="Create a password"
          serverError={state.fieldErrors?.password}
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

        <FormCheckboxField
          control={form.control}
          disabled={isPending}
          label={
            <>
              I agree to the{" "}
              <Link className="font-medium" href={ROUTES.LEGAL_TERMS} target="_blank">
                Terms of Service
              </Link>{" "}
              and{" "}
              <Link className="font-medium" href={ROUTES.LEGAL_PRIVACY} target="_blank">
                Privacy Policy
              </Link>
              .
            </>
          }
          name="acceptTerms"
          serverError={state.fieldErrors?.acceptTerms}
        />

        <Button className="w-full" disabled={isPending} size="lg" type="submit">
          {isPending ? (
            <>
              <Loader2 aria-hidden className="animate-spin" />
              Creating account…
            </>
          ) : (
            "Create account"
          )}
        </Button>
      </form>
    </Form>
  );
}
