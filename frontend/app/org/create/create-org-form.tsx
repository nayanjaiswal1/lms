"use client";

import { useActionState, startTransition, useId, useRef } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Loader2 } from "lucide-react";

import { createOrgAction, type CreateOrgState } from "@/app/org/create/actions";
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

// ─── Schema ───────────────────────────────────────────────────────────────────

const SLUG_RE = /^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/;

const schema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters.").max(100, "Name must be at most 100 characters."),
  slug: z
    .string()
    .min(3, "Slug must be at least 3 characters.")
    .max(63, "Slug must be at most 63 characters.")
    .regex(SLUG_RE, "Lowercase letters, numbers, and hyphens only."),
  description: z.string().max(500, "Description must be at most 500 characters.").optional(),
});

type FormValues = z.infer<typeof schema>;

// ─── Slug helpers ─────────────────────────────────────────────────────────────

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 63);
}

// ─── Component ────────────────────────────────────────────────────────────────

const INITIAL_STATE: CreateOrgState = {};

export function CreateOrgForm() {
  const [state, formAction, isPending] = useActionState(createOrgAction, INITIAL_STATE);
  const idempotencyKeyRef = useRef(
    `${Date.now()}-${Math.random().toString(36).slice(2)}`,
  );
  const idempotencyId = useId();

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { name: "", slug: "", description: "" },
    mode: "onTouched",
  });

  const onSubmit = form.handleSubmit((values) => {
    const data = new FormData();
    data.set("name", values.name);
    data.set("slug", values.slug);
    data.set("description", values.description ?? "");
    data.set("idempotency_key", idempotencyKeyRef.current);
    startTransition(() => formAction(data));
  });

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={onSubmit}>
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
        <p className="text-xs text-muted-foreground -mt-2">
          Your org URL: <span className="font-mono">mindforge.app/<span className="text-foreground">{form.watch("slug") || "your-slug"}</span></span>
        </p>

        {/* Description */}
        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Description <span className="text-muted-foreground font-normal">(optional)</span></FormLabel>
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

        {/* Hidden idempotency key */}
        <input
          id={idempotencyId}
          type="hidden"
          name="idempotency_key"
          value={idempotencyKeyRef.current}
          readOnly
        />

        <Button type="submit" disabled={isPending} className="w-full">
          {isPending ? (
            <>
              <Loader2 aria-hidden className="animate-spin" />
              Creating…
            </>
          ) : (
            "Create organization"
          )}
        </Button>
      </form>
    </Form>
  );
}
