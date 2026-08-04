"use client";

import { useActionState, startTransition } from "react";
import Link from "next/link";
import { Loader2 } from "lucide-react";

import { acceptLegalDocsAction, type AcceptLegalState } from "@/app/legal/accept/actions";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import ROUTES from "@/lib/routes";

const INITIAL_STATE: AcceptLegalState = {};

interface AcceptLegalFormProps {
  needsTerms: boolean;
  needsPrivacy: boolean;
  next?: string;
}

export function AcceptLegalForm({ needsTerms, needsPrivacy, next }: AcceptLegalFormProps) {
  const docTypes = [needsTerms && "terms", needsPrivacy && "privacy"].filter(Boolean) as string[];
  const boundAction = (_prev: AcceptLegalState) => acceptLegalDocsAction(docTypes, next, _prev);
  const [state, formAction, isPending] = useActionState(boundAction, INITIAL_STATE);

  return (
    <form
      className="form-stack"
      onSubmit={(e) => {
        e.preventDefault();
        startTransition(() => formAction());
      }}
    >
      <div className="flex items-start gap-2.5">
        <Checkbox required className="mt-0.5" disabled={isPending} id="accept-legal" />
        <label className="text-sm leading-relaxed text-muted-foreground" htmlFor="accept-legal">
          I agree to the updated{" "}
          {needsTerms && (
            <Link className="font-medium" href={ROUTES.LEGAL_TERMS} target="_blank">
              Terms of Service
            </Link>
          )}
          {needsTerms && needsPrivacy && " and "}
          {needsPrivacy && (
            <Link className="font-medium" href={ROUTES.LEGAL_PRIVACY} target="_blank">
              Privacy Policy
            </Link>
          )}
          .
        </label>
      </div>

      {state.error && <p className="text-sm text-destructive">{state.error}</p>}

      <Button className="w-full" disabled={isPending} size="lg" type="submit">
        {isPending ? (
          <>
            <Loader2 aria-hidden className="animate-spin" />
            Continuing…
          </>
        ) : (
          "Continue"
        )}
      </Button>
    </form>
  );
}
