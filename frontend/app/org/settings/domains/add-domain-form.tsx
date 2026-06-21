"use client";

import { useActionState } from "react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { addDomainAction, type DomainActionState } from "@/app/org/settings/domains/actions";

interface AddDomainFormProps {
  orgId: string;
}

export function AddDomainForm({ orgId }: AddDomainFormProps) {
  const [state, action, isPending] = useActionState<DomainActionState, FormData>(
    addDomainAction,
    {},
  );

  return (
    <form action={action} className="space-y-4">
      <input type="hidden" name="org_id" value={orgId} />

      <div className="stack-md">
        <div className="flex-1 space-y-1.5">
          <Label htmlFor="domain-input">Domain</Label>
          <Input
            id="domain-input"
            name="domain"
            placeholder="example.com"
            required
            type="text"
          />
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="verification-method">Verification method</Label>
          <Select defaultValue="dns_txt" name="verification_method">
            <SelectTrigger id="verification-method" aria-label="Select verification method">
              <SelectValue placeholder="Select method" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="dns_txt">DNS TXT record</SelectItem>
              <SelectItem value="email">Email verification</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      {state.error && (
        <p className="text-sm text-destructive" role="alert">{state.error}</p>
      )}

      <Button disabled={isPending} type="submit">
        {isPending ? "Adding…" : "Add Domain"}
      </Button>
    </form>
  );
}
