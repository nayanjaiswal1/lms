"use client";

import { useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { createEntryQnaAction, createStandaloneQnaAction } from "@/lib/interview-exp/actions";

const QnaSchema = z.object({
  question: z.string().min(1, "Ask a question first.").max(2000),
  answer: z.string().max(4000).optional(),
});

type QnaFormData = z.infer<typeof QnaSchema>;

// A discriminated union so the branch below is exhaustively typed — no
// non-null assertion needed to pick which action to call.
type QnaTarget = { type: "post"; id: string } | { type: "entry"; id: string };

interface AddQnaFormProps {
  target: QnaTarget;
  onDone?: () => void;
}

export function AddQnaForm({ target, onDone }: AddQnaFormProps) {
  const [serverError, setServerError] = useState<string | undefined>();

  const form = useForm<QnaFormData>({
    resolver: zodResolver(QnaSchema),
    defaultValues: { question: "", answer: "" },
  });

  async function onSubmit(data: QnaFormData) {
    setServerError(undefined);
    const input = { question: data.question, answer: data.answer || undefined };
    const result =
      target.type === "entry"
        ? await createEntryQnaAction(target.id, input)
        : await createStandaloneQnaAction(target.id, input);
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
        <FormField
          control={form.control}
          name="question"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Question</FormLabel>
              <FormControl>
                <Textarea
                  className="resize-none text-sm"
                  disabled={pending}
                  placeholder="What did they ask you?"
                  rows={2}
                  {...field}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="answer"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Your answer (optional)</FormLabel>
              <FormControl>
                <Textarea
                  className="resize-none text-sm"
                  disabled={pending}
                  placeholder="How did you answer it?"
                  rows={3}
                  {...field}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        {serverError && <p className="text-sm text-destructive">{serverError}</p>}
        <Button className="self-end" disabled={pending} size="sm" type="submit">
          {pending ? "Posting…" : "Add question"}
        </Button>
      </form>
    </Form>
  );
}
