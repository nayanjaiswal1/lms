"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { saveNomineeAction, type Nominee, type NomineeState } from "@/app/(app)/settings/privacy/actions";

const INITIAL_STATE: NomineeState = {};

interface NomineeCardProps {
  nominee: Nominee | null;
}

// Nominee who may exercise the user's data rights on their behalf (DPDP s.14).
// Saving all three fields blank clears the nominee.
export function NomineeCard({ nominee }: NomineeCardProps) {
  const [state, formAction, pending] = useActionState(saveNomineeAction, INITIAL_STATE);

  return (
    <section aria-labelledby="nominee-heading" className="card-base p-6 space-y-4">
      <div>
        <h2 className="text-lg font-semibold text-foreground" id="nominee-heading">
          Nominee
        </h2>
        <p className="text-sm text-muted-foreground">
          Name someone who can exercise your data rights if you die or become incapacitated. Leave
          all fields blank to remove your nominee.
        </p>
      </div>
      <form action={formAction} className="space-y-4">
        <div className="grid gap-4 md:grid-cols-3">
          <div className="space-y-2">
            <Label htmlFor="nominee-name">Full name</Label>
            <Input defaultValue={nominee?.name ?? ""} disabled={pending} id="nominee-name" maxLength={200} name="name" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="nominee-relationship">Relationship</Label>
            <Input
              defaultValue={nominee?.relationship ?? ""}
              disabled={pending}
              id="nominee-relationship"
              maxLength={200}
              name="relationship"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="nominee-contact">Email or phone</Label>
            <Input defaultValue={nominee?.contact ?? ""} disabled={pending} id="nominee-contact" maxLength={200} name="contact" />
          </div>
        </div>
        {state.error ? (
          <p className="text-sm text-destructive" role="alert">
            {state.error}
          </p>
        ) : null}
        {state.saved ? (
          <p className="text-sm text-muted-foreground" role="status">
            Nominee saved.
          </p>
        ) : null}
        <Button disabled={pending} size="sm" type="submit">
          Save nominee
        </Button>
      </form>
    </section>
  );
}
