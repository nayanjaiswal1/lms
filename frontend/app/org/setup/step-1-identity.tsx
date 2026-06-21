"use client";

import { useActionState, startTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { ArrowRight, Loader2 } from "lucide-react";

import { saveStep1Action, type SaveStepState } from "@/app/org/setup/actions";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { FormInputField } from "@/components/ui/form-input-field";
import {
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Textarea } from "@/components/ui/textarea";
import type { Org } from "@/lib/orgs/types";

// ─── Schema ───────────────────────────────────────────────────────────────────

const SLUG_RE = /^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/;

const schema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters.").max(100, "Name must be at most 100 characters."),
  slug: z
    .string()
    .min(3, "Slug must be at least 3 characters.")
    .max(63, "Slug must be at most 63 characters.")
    .regex(SLUG_RE, "Lowercase letters, numbers, and hyphens only."),
  description: z
    .string()
    .max(500, "Description must be at most 500 characters.")
    .optional(),
});

type FormValues = z.infer<typeof schema>;

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 63);
}

const INITIAL_STATE: SaveStepState = {};

// ─── Props ────────────────────────────────────────────────────────────────────

interface Step1IdentityProps {
  orgId: string;
  org: Org | null;
}

// ─── Component ────────────────────────────────────────────────────────────────

export function Step1Identity({ orgId, org }: Step1IdentityProps) {
  const [state, formAction, isPending] = useActionState(
    saveStep1Action,
    INITIAL_STATE,
  );

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: org?.name ?? "",
      slug: org?.slug ?? "",
      description: org?.description ?? "",
    },
    mode: "onTouched",
  });

  const onSubmit = form.handleSubmit((values) => {
    const data = new FormData();
    data.set("org_id", orgId);
    data.set("name", values.name);
    data.set("slug", values.slug);
    data.set("description", values.description ?? "");
    startTransition(() => formAction(data));
  });

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={onSubmit}>
        <div className="mb-2">
          <h2 className="section-title">Identity</h2>
          <p className="text-sm text-muted-foreground">
            Set your organization's name and URL slug.
          </p>
        </div>

        {state.error && (
          <p role="alert" className="rounded-md border border-border bg-muted px-3 py-2.5 text-sm text-destructive">
            {state.error}
          </p>
        )}

        {/* Name */}
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Organization name</FormLabel>
              <FormControl>
                <Input
                  placeholder="Acme Corp"
                  maxLength={100}
                  disabled={isPending}
                  {...field}
                  onChange={(e) => {
                    field.onChange(e);
                    if (!form.formState.touchedFields.slug) {
                      form.setValue("slug", slugify(e.target.value));
                    }
                  }}
                />
              </FormControl>
              <FormMessage>{state.fieldErrors?.name}</FormMessage>
            </FormItem>
          )}
        />

        {/* Slug */}
        <FormInputField
          control={form.control}
          name="slug"
          label="Slug"
          placeholder="acme-corp"
          maxLength={63}
          disabled={isPending}
          serverError={state.fieldErrors?.slug}
        />

        {/* Description */}
        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>
                Description{" "}
                <span className="font-normal text-muted-foreground">(optional)</span>
              </FormLabel>
              <FormControl>
                <Textarea
                  placeholder="What does your organization do?"
                  maxLength={500}
                  rows={3}
                  disabled={isPending}
                  {...field}
                />
              </FormControl>
              <FormDescription>Up to 500 characters.</FormDescription>
              <FormMessage>{state.fieldErrors?.description}</FormMessage>
            </FormItem>
          )}
        />

        <div className="flex justify-end pt-2">
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
