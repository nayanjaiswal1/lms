"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { TagInput } from "@/components/ui/tag-input";
import { createPostAction } from "@/lib/interview-exp/actions";
import ROUTES from "@/lib/routes";

const PostSchema = z.object({
  company: z.string().min(1, "Which company?").max(200),
  position: z.string().min(1, "Which position?").max(200),
  title: z.string().min(1, "Give it a short title.").max(300),
  tags: z.array(z.string().max(50)).max(20),
});

type PostFormData = z.infer<typeof PostSchema>;

export function CreatePostForm() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | undefined>();

  const form = useForm<PostFormData>({
    resolver: zodResolver(PostSchema),
    defaultValues: { company: "", position: "", title: "", tags: [] },
  });

  async function onSubmit(data: PostFormData) {
    setServerError(undefined);
    const result = await createPostAction({
      company: data.company,
      position: data.position,
      title: data.title,
      tags: data.tags,
    });
    if (!result.ok || !result.data) {
      setServerError(result.error ?? "Something went wrong.");
      return;
    }
    router.push(ROUTES.interviewExpPost(result.data.id));
  }

  const pending = form.formState.isSubmitting;

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <div className="stack-sm">
          <FormInputField
            control={form.control}
            disabled={pending}
            label="Company"
            name="company"
            placeholder="e.g. Google"
          />
          <FormInputField
            control={form.control}
            disabled={pending}
            label="Position"
            name="position"
            placeholder="e.g. Backend Engineer L4"
          />
        </div>
        <FormInputField
          control={form.control}
          disabled={pending}
          label="Title"
          name="title"
          placeholder="e.g. Onsite loop — 4 rounds, system design heavy"
        />
        <FormField
          control={form.control}
          name="tags"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Tags (optional)</FormLabel>
              <FormControl>
                <TagInput
                  disabled={pending}
                  placeholder="react, node, system-design"
                  value={field.value}
                  onChange={field.onChange}
                />
              </FormControl>
              <FormDescription>Press Enter or comma to add — languages, frameworks, topics.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        {serverError && (
          <p className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">{serverError}</p>
        )}
        <Button className="w-full sm:w-auto" disabled={pending} type="submit">
          {pending ? "Creating…" : "Create post"}
        </Button>
      </form>
    </Form>
  );
}
