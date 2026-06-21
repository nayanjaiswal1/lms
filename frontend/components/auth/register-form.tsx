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
    },
    mode: "onTouched",
  });

  const onSubmit = form.handleSubmit((values) => {
    const data = new FormData();
    Object.entries(values).forEach(([key, value]) => data.set(key, value));
    startTransition(() => formAction(data));
  });

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={onSubmit}>
        <AuthFormError message={state.error} />

        <FormInputField
          control={form.control}
          name="name"
          label="Full name"
          autoComplete="name"
          placeholder="Alex Morgan"
          disabled={isPending}
          serverError={state.fieldErrors?.name}
        />

        <FormInputField
          control={form.control}
          name="email"
          label="Email"
          type="email"
          inputMode="email"
          autoComplete="email"
          placeholder="you@example.com"
          disabled={isPending}
          serverError={state.fieldErrors?.email}
        />

        <FormInputField
          control={form.control}
          name="password"
          label="Password"
          type="password"
          autoComplete="new-password"
          placeholder="Create a password"
          disabled={isPending}
          description="8–72 characters"
          serverError={state.fieldErrors?.password}
        />

        <FormInputField
          control={form.control}
          name="confirmPassword"
          label="Confirm password"
          type="password"
          autoComplete="new-password"
          placeholder="Enter it again"
          disabled={isPending}
          serverError={state.fieldErrors?.confirmPassword}
        />

        <p className="text-xs leading-relaxed text-muted-foreground">
          By creating an account, you agree to our{" "}
          <Link href={ROUTES.HOME} className="font-medium">
            Terms
          </Link>{" "}
          and{" "}
          <Link href={ROUTES.HOME} className="font-medium">
            Privacy Policy
          </Link>
          .
        </p>

        <Button type="submit" size="lg" disabled={isPending} className="w-full">
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
