"use client";

import { useActionState, startTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { ArrowLeft, ArrowRight, Loader2 } from "lucide-react";
import Link from "next/link";

import { saveStep3Action, type SaveStepState } from "@/app/org/setup/actions";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import ROUTES from "@/lib/routes";
import type { Org } from "@/lib/orgs/types";

// ─── Schema ───────────────────────────────────────────────────────────────────

const schema = z.object({
  seat_limit: z
    .string()
    .optional()
    .refine(
      (val) => {
        if (!val || val.trim() === "") return true;
        const n = parseInt(val, 10);
        return !isNaN(n) && n >= 1;
      },
      { message: "Seat limit must be a positive number." },
    ),
});

type FormValues = z.infer<typeof schema>;

const INITIAL_STATE: SaveStepState = {};

interface Step3PlanProps {
  orgId: string;
  org: Org | null;
}

export function Step3Plan({ orgId, org }: Step3PlanProps) {
  const [state, formAction, isPending] = useActionState(
    saveStep3Action,
    INITIAL_STATE,
  );

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      seat_limit: org?.seat_limit != null ? String(org.seat_limit) : "",
    },
    mode: "onTouched",
  });

  const onSubmit = form.handleSubmit((values) => {
    const data = new FormData();
    data.set("org_id", orgId);
    data.set("seat_limit", values.seat_limit ?? "");
    startTransition(() => formAction(data));
  });

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={onSubmit}>
        <div className="mb-2">
          <h2 className="section-title">Plan &amp; Limits</h2>
          <p className="text-sm text-muted-foreground">
            Control how many members can be in your organization.
          </p>
        </div>

        {state.error && (
          <p role="alert" className="rounded-md border border-border bg-muted px-3 py-2.5 text-sm text-destructive">
            {state.error}
          </p>
        )}

        <FormInputField
          control={form.control}
          name="seat_limit"
          label="Seat limit"
          type="number"
          inputMode="numeric"
          min="1"
          placeholder="Leave blank for unlimited"
          disabled={isPending}
          serverError={state.fieldErrors?.seat_limit}
        />
        <p className="text-xs text-muted-foreground -mt-2">
          Maximum number of active members allowed. Leave blank for unlimited.
        </p>

        <div className="flex items-center justify-between pt-2">
          <Button
            type="button"
            variant="outline"
            disabled={isPending}
            className="gap-2"
            asChild
          >
            <Link href={`${ROUTES.ORG_SETUP}?step=2`}>
              <ArrowLeft aria-hidden className="h-4 w-4" />
              Back
            </Link>
          </Button>

          <Button type="submit" disabled={isPending} className="gap-2">
            {isPending ? (
              <>
                <Loader2 aria-hidden className="animate-spin" />
                Saving…
              </>
            ) : (
              <>
                Next <ArrowRight aria-hidden className="h-4 w-4" />
              </>
            )}
          </Button>
        </div>
      </form>
    </Form>
  );
}
