"use client";

import { useActionState } from "react";
import { Loader2, Building2, ChevronRight } from "lucide-react";

import { selectOrgAction, type SelectOrgState } from "@/app/org-select/actions";
import { AuthFormError } from "@/components/auth/auth-form-error";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface Org {
  id: string;
  slug: string;
  name: string;
  role: string;
}

interface OrgSelectListProps {
  orgs: Org[];
}

const INITIAL_STATE: SelectOrgState = {};

export function OrgSelectList({ orgs }: OrgSelectListProps) {
  const [state, formAction, isPending] = useActionState(selectOrgAction, INITIAL_STATE);

  return (
    <div className="flex flex-col gap-4">
      <AuthFormError message={state.error} />

      <ul className="flex flex-col gap-2" role="list">
        {orgs.map((org) => (
          <li key={org.id}>
            <form action={formAction}>
              <input type="hidden" name="org_id" value={org.id} />
              <button
                type="submit"
                disabled={isPending}
                className={cn(
                  "card-interactive flex w-full items-center gap-4 p-4 text-left",
                  "disabled:pointer-events-none disabled:opacity-60",
                )}
              >
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-muted">
                  <Building2 aria-hidden className="h-5 w-5 text-muted-foreground" />
                </span>
                <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                  <span className="truncate font-semibold text-foreground">{org.name}</span>
                  <span className="truncate text-xs capitalize text-muted-foreground">{org.role}</span>
                </span>
                {isPending ? (
                  <Loader2 aria-hidden className="h-4 w-4 shrink-0 animate-spin text-muted-foreground" />
                ) : (
                  <ChevronRight aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
                )}
              </button>
            </form>
          </li>
        ))}
      </ul>
    </div>
  );
}
