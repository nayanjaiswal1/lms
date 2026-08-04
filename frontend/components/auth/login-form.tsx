"use client";

import Link from "next/link";
import { useActionState, startTransition, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";

import { loginAction, type LoginState } from "@/app/login/actions";
import { AuthFormError } from "@/components/auth/auth-form-error";
import { SocialLoginButtons } from "@/components/auth/social-login-buttons";
import { PasskeyAutofill } from "@/components/auth/passkey-autofill";
import { loginSchema, type LoginInput } from "@/lib/validation/auth";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import ROUTES from "@/lib/routes";

const INITIAL_STATE: LoginState = {};

interface LoginFormProps {
  oauthError?: string;
  next?: string;
}

const OAUTH_ERROR_MESSAGES: Record<string, string> = {
  state_mismatch: "Login failed due to a security check. Please try again.",
  exchange_failed: "Could not complete social login. Please try again.",
  missing_code: "OAuth provider did not return a code. Please try again.",
  unknown_provider: "Unknown social login provider.",
  account_error: "Could not create or link your account. Please try again.",
  userinfo_failed: "Could not retrieve your profile from the provider.",
  network: "Network error during social login. Please try again.",
  server_error: "A server error occurred. Please try again.",
  missing_token: "Session token missing. Please try again.",
  config: "Authentication is not configured. Contact support.",
};

export function LoginForm({ oauthError, next }: LoginFormProps) {
  const [state, formAction, isPending] = useActionState(loginAction, INITIAL_STATE);
  // Set the instant a provider link is followed — the OAuth redirect takes
  // over the page shortly after, but until it does every other control
  // (submit, the other provider, the fields) should be locked too.
  const [socialPending, setSocialPending] = useState(false);
  const locked = isPending || socialPending;

  const form = useForm<LoginInput>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "" },
    mode: "onTouched",
  });

  const onSubmit = form.handleSubmit((values) => {
    const data = new FormData();
    data.set("email", values.email);
    data.set("password", values.password);
    if (next) data.set("next", next);
    startTransition(() => formAction(data));
  });

  const oauthMessage = oauthError
    ? (OAUTH_ERROR_MESSAGES[oauthError] ?? "Social login failed. Please try again.")
    : undefined;

  return (
    <div className="form-stack">
      <PasskeyAutofill next={next} />
      <SocialLoginButtons disabled={locked} onProviderSelect={() => setSocialPending(true)} />

      <div className="divider-label">or continue with email</div>

      <Form {...form}>
        <form noValidate className="form-stack" onSubmit={onSubmit}>
          <AuthFormError message={oauthMessage ?? state.error} />

          <FormInputField
            control={form.control}
            name="email"
            label="Email"
            type="email"
            inputMode="email"
            // "webauthn" alongside the normal token turns on conditional UI —
            // the browser lists matching passkeys in this field's own
            // autofill dropdown (see components/auth/passkey-autofill.tsx).
            autoComplete="email webauthn"
            placeholder="you@example.com"
            disabled={locked}
            serverError={state.fieldErrors?.email}
          />

          <FormInputField
            control={form.control}
            name="password"
            label="Password"
            type="password"
            autoComplete="current-password"
            placeholder="Enter your password"
            disabled={locked}
            serverError={state.fieldErrors?.password}
          />

          <Link
            href={ROUTES.FORGOT_PASSWORD}
            className="-mt-2 self-end text-xs font-medium"
          >
            Forgot password?
          </Link>

          <Button type="submit" size="lg" disabled={locked} className="mt-1 w-full">
            {isPending ? (
              <>
                <Loader2 aria-hidden className="animate-spin" />
                Signing in…
              </>
            ) : (
              "Sign in"
            )}
          </Button>
        </form>
      </Form>
    </div>
  );
}
