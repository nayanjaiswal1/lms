"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { loginPasskeyBeginAction, loginPasskeyFinishAction } from "@/app/login/actions";
import { prepareRequestOptions, serializeAssertedCredential } from "@/lib/webauthn";
import ROUTES from "@/lib/routes";

interface PasskeyAutofillProps {
  next?: string;
}

// Conditional UI (WebAuthn "autofill-assisted" passkeys): the browser lists
// matching passkeys directly inside the email field's own autofill dropdown
// the moment the user focuses it — no separate button, matching the flow at
// accounts.google.com. Requires the email input to carry
// autoComplete="email webauthn" (see login-form.tsx).
//
// This is a documented exception to the no-useEffect rule: starting an
// abortable navigator.credentials.get({mediation: "conditional"}) call once
// on mount, with cleanup on unmount, is exactly the "subscribe to an external
// system" case useEffect exists for — there is no server-component, use(), or
// URL-state equivalent for an imperative, cancelable browser credential API.
export function PasskeyAutofill({ next }: PasskeyAutofillProps) {
  const router = useRouter();

  useEffect(() => {
    if (typeof window === "undefined" || !("PublicKeyCredential" in window)) return;
    const isConditionalMediationAvailable = PublicKeyCredential.isConditionalMediationAvailable;
    if (!isConditionalMediationAvailable) return;

    const controller = new AbortController();

    (async () => {
      const available = await isConditionalMediationAvailable();
      if (!available || controller.signal.aborted) return;

      const begin = await loginPasskeyBeginAction();
      if (!begin.ok || !begin.data || controller.signal.aborted) return;

      const credential = (await navigator.credentials.get({
        ...prepareRequestOptions(begin.data.options),
        mediation: "conditional",
        signal: controller.signal,
      })) as PublicKeyCredential | null;
      if (!credential) return;

      const result = await loginPasskeyFinishAction(
        begin.data.handle,
        serializeAssertedCredential(credential),
        next,
      );
      if (result.error) {
        toast.error(result.error);
        return;
      }
      router.push(result.redirectTo ?? ROUTES.DASHBOARD);
    })().catch((err: unknown) => {
      // AbortError fires on unmount/navigation (or a second conditional
      // request superseding this one) — expected, not a failure to report.
      if (err instanceof Error && err.name === "AbortError") return;
      console.error("[passkey] conditional sign-in failed:", err);
      const detail = err instanceof Error ? `${err.name}: ${err.message}` : "";
      toast.error(detail ? `Passkey sign-in failed: ${detail}` : "Passkey sign-in failed. Please try again.");
    });

    return () => controller.abort();
  }, [next, router]);

  return null;
}
