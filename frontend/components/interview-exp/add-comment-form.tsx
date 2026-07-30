"use client";

import { useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormMessage } from "@/components/ui/form";
import { createCommentAction } from "@/lib/interview-exp/actions";

const CommentSchema = z.object({
  content: z.string().min(1, "Write a reply first.").max(4000),
});

type CommentFormData = z.infer<typeof CommentSchema>;

interface AddCommentFormProps {
  qnaId: string;
  parentId?: string;
  placeholder?: string;
  onDone?: () => void;
}

export function AddCommentForm({ qnaId, parentId, placeholder, onDone }: AddCommentFormProps) {
  const [serverError, setServerError] = useState<string | undefined>();

  const form = useForm<CommentFormData>({
    resolver: zodResolver(CommentSchema),
    defaultValues: { content: "" },
  });

  async function onSubmit(data: CommentFormData) {
    setServerError(undefined);
    const result = await createCommentAction(qnaId, { content: data.content, parent_id: parentId });
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
      <form className="flex flex-col gap-2" onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="content"
          render={({ field }) => (
            <FormItem>
              <FormControl>
                <Textarea
                  className="resize-none text-sm"
                  disabled={pending}
                  placeholder={placeholder ?? "Add a reply…"}
                  rows={2}
                  {...field}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        {serverError && <p className="text-sm text-destructive">{serverError}</p>}
        <Button className="self-end" disabled={pending} size="sm" type="submit">
          {pending ? "Posting…" : "Reply"}
        </Button>
      </form>
    </Form>
  );
}
