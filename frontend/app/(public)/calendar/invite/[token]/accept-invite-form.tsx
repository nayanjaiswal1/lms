"use client";

import { useActionState } from "react";
import Link from "next/link";
import { CalendarCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { acceptCalendarInviteAction } from "@/lib/server/calendar";
import ROUTES from "@/lib/routes";
import type { ActionResult } from "@/lib/server/api";
import type { CalendarEvent } from "@/lib/calendar/types";

interface AcceptInviteFormProps {
  token: string;
}

type AcceptState = ActionResult<CalendarEvent>;
const initialState: AcceptState = {};

export function AcceptInviteForm({ token }: AcceptInviteFormProps) {
  async function submit(_prev: AcceptState): Promise<AcceptState> {
    return acceptCalendarInviteAction(token);
  }

  const [state, formAction, pending] = useActionState<AcceptState, FormData>(submit, initialState);

  if (state.ok && state.data) {
    return (
      <div className="flex flex-col items-center gap-4 text-center">
        <CalendarCheck aria-hidden className="h-12 w-12 text-primary" />
        <div>
          <h1 className="page-title">You&apos;re in</h1>
          <p className="mt-2 text-muted-foreground">
            You&apos;ve been added to <span className="font-semibold text-foreground">{state.data.title}</span>.
          </p>
        </div>
        <Link href={ROUTES.CALENDAR}>
          <Button>Go to your calendar</Button>
        </Link>
      </div>
    );
  }

  return (
    <form action={formAction} className="flex flex-col items-center gap-4 text-center">
      <CalendarCheck aria-hidden className="h-12 w-12 text-muted-foreground" />
      <div>
        <h1 className="page-title">Calendar invite</h1>
        <p className="mt-2 text-muted-foreground">
          Accept to join this event. If you don&apos;t have a MindForge account yet, one will be created for you.
        </p>
      </div>
      {state.error && <p className="auth-error">{state.error}</p>}
      <Button disabled={pending} size="lg" type="submit">
        {pending ? "Accepting…" : "Accept invite"}
      </Button>
    </form>
  );
}
