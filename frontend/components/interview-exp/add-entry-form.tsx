"use client";

import { useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { createEntryAction } from "@/lib/interview-exp/actions";

const EntrySchema = z.object({
  round_label: z.string().min(1, "Give this round a label.").max(200),
  content: z.string().min(1, "Describe what happened.").max(8000),
});

type EntryFormData = z.infer<typeof EntrySchema>;

interface AddEntryFormProps {
  postId: string;
  onDone?: () => void;
}

export function AddEntryForm({ postId, onDone }: AddEntryFormProps) {
  const [serverError, setServerError] = useState<string | undefined>();

  const form = useForm<EntryFormData>({
    resolver: zodResolver(EntrySchema),
    defaultValues: { round_label: "", content: "" },
  });

  async function onSubmit(data: EntryFormData) {
    setServerError(undefined);
    const result = await createEntryAction(postId, data);
    if (!result.ok) {
      setServerError(result.error ?? "Something went wrong.");
      return;
    }
    form.reset();
    onDone?.();
  }

  const pending = form.formState.isSubmitting;

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField
          control={form.control}
          disabled={pending}
          label="Round"
          name="round_label"
          placeholder="e.g. Onsite Round 2"
        />
        <FormField
          control={form.control}
          name="content"
          render={({ field }) => (
            <FormItem>
              <FormLabel>What happened</FormLabel>
              <FormControl>
                <Textarea
                  className="resize-none text-sm"
                  disabled={pending}
                  placeholder="Walk through this round — format, interviewer style, how it went…"
                  rows={5}
                  {...field}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        {serverError && <p className="text-sm text-destructive">{serverError}</p>}
        <Button className="self-end" disabled={pending} type="submit">
          {pending ? "Adding…" : "Add round"}
        </Button>
      </form>
    </Form>
  );
}
