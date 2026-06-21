"use client";

import { useActionState } from "react";
import { CheckCircle2, XCircle } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { Domain } from "@/lib/orgs/types";
import {
  verifyDomainAction,
  toggleAutoJoinAction,
  removeDomainAction,
  type DomainActionState,
} from "@/app/org/settings/domains/actions";

interface DomainCardProps {
  domain: Domain;
  orgId: string;
}

function DomainCard({ domain, orgId }: DomainCardProps) {
  const [verifyState, verifyAction, verifyPending] = useActionState<DomainActionState, FormData>(
    verifyDomainAction,
    {},
  );
  const [toggleState, toggleAction] = useActionState<DomainActionState, FormData>(
    toggleAutoJoinAction,
    {},
  );
  const [removeState, removeAction, removePending] = useActionState<DomainActionState, FormData>(
    removeDomainAction,
    {},
  );

  const error = verifyState.error ?? toggleState.error ?? removeState.error;

  return (
    <div className="card-base p-5 space-y-4">
      {/* Header row */}
      <div className="flex flex-wrap items-center gap-3 justify-between">
        <div className="flex items-center gap-2">
          <span className="font-mono text-sm font-medium text-foreground">{domain.domain}</span>
          {domain.verified ? (
            <Badge className="gap-1" variant="default">
              <CheckCircle2 aria-hidden className="h-3 w-3" /> Verified
            </Badge>
          ) : (
            <Badge className="gap-1" variant="outline">
              <XCircle aria-hidden className="h-3 w-3 text-muted-foreground" /> Unverified
            </Badge>
          )}
        </div>

        {/* Auto-join toggle */}
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">Auto-join:</span>
          <form action={toggleAction}>
            <input type="hidden" name="org_id" value={orgId} />
            <input type="hidden" name="domain_id" value={domain.id} />
            <input type="hidden" name="enabled" value={domain.auto_join_enabled ? "false" : "true"} />
            <button
              aria-label={
                domain.auto_join_enabled
                  ? `Disable auto-join for ${domain.domain}`
                  : `Enable auto-join for ${domain.domain}`
              }
              className={[
                "relative inline-flex h-5 w-9 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-[--duration-normal]",
                domain.auto_join_enabled ? "bg-primary" : "bg-muted",
              ].join(" ")}
              role="switch"
              aria-checked={domain.auto_join_enabled}
              type="submit"
            >
              <span
                className={[
                  "pointer-events-none inline-block h-4 w-4 rounded-full bg-background shadow-card transition-transform duration-[--duration-normal]",
                  domain.auto_join_enabled ? "translate-x-4" : "translate-x-0",
                ].join(" ")}
              />
            </button>
            <span className="text-xs text-muted-foreground ml-1">
              {domain.auto_join_enabled ? "ON" : "OFF"}
            </span>
          </form>
        </div>
      </div>

      {/* Verification token */}
      {!domain.verified && (
        <div className="rounded-md bg-muted p-3 space-y-1">
          <p className="text-xs font-medium text-muted-foreground">
            {domain.verification_method === "email"
              ? "Check your domain admin email for the verification link."
              : "Add this DNS TXT record to verify domain ownership:"}
          </p>
          <p className="font-mono text-xs text-foreground break-all select-all">
            {domain.verification_token}
          </p>
        </div>
      )}

      {/* Actions */}
      <div className="flex items-center gap-2 flex-wrap">
        {!domain.verified && (
          <form action={verifyAction}>
            <input type="hidden" name="org_id" value={orgId} />
            <input type="hidden" name="domain_id" value={domain.id} />
            <Button disabled={verifyPending} size="sm" type="submit" variant="secondary">
              {verifyPending ? "Checking…" : "Verify Now"}
            </Button>
          </form>
        )}

        <form action={removeAction}>
          <input type="hidden" name="org_id" value={orgId} />
          <input type="hidden" name="domain_id" value={domain.id} />
          <Button
            aria-label={`Remove domain ${domain.domain}`}
            disabled={removePending}
            size="sm"
            type="submit"
            variant="destructive"
          >
            Delete
          </Button>
        </form>
      </div>

      {error && (
        <p className="text-xs text-destructive" role="alert">{error}</p>
      )}
    </div>
  );
}

interface DomainListProps {
  domains: Domain[];
  orgId: string;
}

export function DomainList({ domains, orgId }: DomainListProps) {
  if (domains.length === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">No domains added yet.</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {domains.map((domain) => (
        <DomainCard domain={domain} key={domain.id} orgId={orgId} />
      ))}
    </div>
  );
}
