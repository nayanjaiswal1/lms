"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { acceptBatchInvitationAction, declineBatchInvitationAction } from "@/app/invitations/accept/actions";
import type { ActionResult } from "@/lib/server/api";

interface InvitationResponseFormProps {
  token: string;
}

type ResponseState = ActionResult & { declined?: boolean };

export function InvitationResponseForm({ token }: InvitationResponseFormProps) {
  const [state, formAction, pending] = useActionState<ResponseState, FormData>(async (_prev, formData) => {
    if (formData.get("answer") === "decline") {
      const result = await declineBatchInvitationAction(token);
      return result.error ? result : { declined: true };
    }
    return acceptBatchInvitationAction(token);
  }, {});

  if (state.declined) {
    return <p className="text-center text-muted-foreground">You declined this invitation.</p>;
  }

  return (
    <form action={formAction} className="flex flex-col gap-3">
      {state.error && <p className="auth-error text-center">{state.error}</p>}
      <Button disabled={pending} name="answer" size="lg" type="submit" value="accept">
        {pending ? "Saving…" : "Accept invitation"}
      </Button>
      <Button disabled={pending} name="answer" type="submit" value="decline" variant="ghost">
        Decline
      </Button>
    </form>
  );
}
