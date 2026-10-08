"use client";

import { useActionState } from "react";
import { Building2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { joinOrgAction } from "@/app/orgs/join/actions";
import type { ActionResult } from "@/lib/server/api";

interface JoinOrgFormProps {
  token: string;
}

export function JoinOrgForm({ token }: JoinOrgFormProps) {
  const [state, formAction, pending] = useActionState<ActionResult, FormData>(() => joinOrgAction(token), {});

  return (
    <form action={formAction} className="flex flex-col items-center gap-4 text-center">
      <Building2 aria-hidden className="h-12 w-12 text-muted-foreground" />
      <div>
        <h1 className="page-title">Organization invite</h1>
        <p className="mt-2 text-muted-foreground">
          Accept to join the organization that invited you. You must be signed in with the email address the invite
          was sent to.
        </p>
      </div>
      {state.error && <p className="auth-error">{state.error}</p>}
      <Button disabled={pending} size="lg" type="submit">
        {pending ? "Joining…" : "Accept invite"}
      </Button>
    </form>
  );
}
