"use client";

import { PLACEHOLDER_DOMAIN } from "@/lib/constants";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { TagInput } from "@/components/ui/tag-input";
import { submitWorkspaceInterestAction } from "@/lib/workspace/actions";

const FALLBACK_MESSAGE = "Thanks — the project owner will review your interest.";

const Schema = z.object({
  name: z.string().min(1, "Name is required.").max(100),
  email: z.string().email("Enter a valid email.").max(254),
  skills: z.array(z.string().max(40)).max(15, "Up to 15 skills."),
  portfolio_url: z
    .string()
    .max(500)
    .refine((v) => v === "" || /^https?:\/\//i.test(v), "Must start with http:// or https://."),
  message: z.string().max(2000),
  website: z.string().max(0).optional(), // honeypot — real users never see or fill this
});
type FormData = z.infer<typeof Schema>;

interface PublicInterestFormProps {
  shareToken: string;
}

export function PublicInterestForm({ shareToken }: PublicInterestFormProps) {
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { name: "", email: "", skills: [], portfolio_url: "", message: "", website: "" },
  });

  async function onSubmit(data: FormData) {
    const result = await submitWorkspaceInterestAction(shareToken, { ...data, website: data.website ?? "" });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    // Same static message for every outcome (new/duplicate/cooldown/honeypot) —
    // no membership or email oracle (see 02-auth-security.md §4.4).
    setSuccessMessage(result.data?.message ?? FALLBACK_MESSAGE);
  }

  if (successMessage) {
    return (
      <div className="empty-state">
        <p className="font-medium">{successMessage}</p>
      </div>
    );
  }

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Name" name="name" placeholder="Jane Doe" />
        <FormInputField control={form.control} label="Email" name="email" placeholder={`jane@${PLACEHOLDER_DOMAIN}`} type="email" />

        <FormField
          control={form.control}
          name="skills"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Skills</FormLabel>
              <FormControl>
                <TagInput placeholder="Add a skill and press Enter…" value={field.value} onChange={field.onChange} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormInputField
          control={form.control}
          label="Portfolio link (optional)"
          name="portfolio_url"
          placeholder="https://github.com/you"
        />

        <FormTextareaField
          control={form.control}
          label="Why this project? (optional)"
          name="message"
          placeholder="Anything you'd like the project owner to know…"
          rows={5}
        />

        {/* Honeypot: real users never see this field (hidden + removed from
            tab order + aria-hidden); a naive bot filling every input trips it,
            and the backend silently drops the submission (see D14). */}
        <FormField
          control={form.control}
          name="website"
          render={({ field }) => (
            <FormItem aria-hidden="true" className="sr-only">
              <FormLabel>Leave this field blank</FormLabel>
              <FormControl>
                <input {...field} autoComplete="off" tabIndex={-1} />
              </FormControl>
            </FormItem>
          )}
        />

        <Button className="self-end px-5 py-2.5" disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Sending…" : "Send interest"}
        </Button>
      </form>
    </Form>
  );
}
