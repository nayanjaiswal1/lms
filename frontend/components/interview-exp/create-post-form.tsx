"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { createPostAction } from "@/lib/interview-exp/actions";
import ROUTES from "@/lib/routes";

const PostSchema = z.object({
  company: z.string().min(1, "Which company?").max(200),
  position: z.string().min(1, "Which position?").max(200),
  title: z.string().min(1, "Give it a short title.").max(300),
  // ponytail: comma-separated text input rather than a dedicated tag-chip
  // widget — this feature only needs a handful of language/framework tags,
  // not a full multi-select component.
  tags: z.string().max(500).optional(),
});

type PostFormData = z.infer<typeof PostSchema>;

export function CreatePostForm() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | undefined>();

  const form = useForm<PostFormData>({
    resolver: zodResolver(PostSchema),
    defaultValues: { company: "", position: "", title: "", tags: "" },
  });

  async function onSubmit(data: PostFormData) {
    setServerError(undefined);
    const tags = (data.tags ?? "")
      .split(",")
      .map((t) => t.trim())
      .filter(Boolean);
    const result = await createPostAction({
      company: data.company,
      position: data.position,
      title: data.title,
      tags,
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
        <FormInputField
          control={form.control}
          description="Comma-separated — languages, frameworks, topics."
          disabled={pending}
          label="Tags (optional)"
          name="tags"
          placeholder="react, node, system-design"
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
