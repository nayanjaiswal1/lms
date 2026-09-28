"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Form, FormField, FormItem, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSwitchField } from "@/components/ui/form-switch-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { BundleCoursePicker } from "@/components/bundles/bundle-course-picker";
import { BundleDeleteButton } from "@/components/bundles/bundle-delete-button";
import { createBundleAction, saveBundleAction } from "@/lib/bundles/actions";
import type { BundleDetail, PickableCourse } from "@/lib/server/bundles";
import ROUTES from "@/lib/routes";

// Mirrors the backend limits in handler_bundles.go.
const BundleSchema = z.object({
  title: z.string().trim().min(3, "Title must be 3–200 characters.").max(200, "Title must be 3–200 characters."),
  description: z.string().max(2000, "Description must be at most 2000 characters."),
  published: z.boolean(),
  course_ids: z.array(z.string()).max(50, "A bundle can hold at most 50 courses."),
});
type BundleValues = z.infer<typeof BundleSchema>;

interface BundleEditorProps {
  bundle: BundleDetail | null; // null = creating a new bundle
  courses: PickableCourse[];
}

export function BundleEditor({ bundle, courses }: BundleEditorProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const form = useForm<BundleValues>({
    resolver: zodResolver(BundleSchema),
    defaultValues: {
      title: bundle?.title ?? "",
      description: bundle?.description ?? "",
      published: bundle?.status === "published",
      course_ids: bundle?.courses.map((c) => c.id) ?? [],
    },
  });

  // Courses already in the bundle stay nameable even when the picker's
  // source (published + own drafts) doesn't include them.
  const pickable = [...courses];
  for (const c of bundle?.courses ?? []) {
    if (!pickable.some((p) => p.id === c.id)) pickable.push({ id: c.id, title: c.title, status: c.status });
  }

  function onSubmit(values: BundleValues) {
    startTransition(async () => {
      const input = {
        title: values.title,
        description: values.description.trim() || null,
        status: values.published ? ("published" as const) : ("draft" as const),
      };
      let bundleID = bundle?.id;
      if (!bundleID) {
        const created = await createBundleAction(input);
        if (!created.ok || !created.data) {
          applyServerErrors(created.fieldErrors);
          toast.error(created.error ?? "Could not create the bundle.");
          return;
        }
        bundleID = created.data.id;
      }
      const saved = await saveBundleAction(bundleID, input, values.course_ids);
      if (!saved.ok || !saved.data) {
        applyServerErrors(saved.fieldErrors);
        toast.error(saved.error ?? "Could not save the bundle.");
        return;
      }
      toast.success("Bundle saved.");
      router.push(ROUTES.bundle(saved.data.slug));
    });
  }

  function applyServerErrors(fields: Record<string, string> | undefined) {
    for (const [name, message] of Object.entries(fields ?? {})) {
      if (name in BundleSchema.shape) form.setError(name as keyof BundleValues, { message });
    }
  }

  return (
    <Form {...form}>
      <form className="flex max-w-3xl flex-col gap-6" onSubmit={form.handleSubmit(onSubmit)}>
        <div className="card-base form-stack p-6">
          <FormInputField control={form.control} label="Title" maxLength={200} name="title" placeholder="e.g. Backend Engineer Path" />
          <FormTextareaField
            control={form.control}
            label="Description"
            maxLength={2000}
            name="description"
            placeholder="What will a student get from taking these courses together?"
            rows={3}
          />
          <FormSwitchField control={form.control} description="Visible to students on the Courses page." label="Published" name="published" />
        </div>

        <div className="card-base flex flex-col gap-4 p-6">
          <h2 className="font-semibold">Courses, in order</h2>
          <FormField
            control={form.control}
            name="course_ids"
            render={({ field }) => (
              <FormItem>
                <BundleCoursePicker courses={pickable} value={field.value} onChange={field.onChange} />
                <FormMessage />
              </FormItem>
            )}
          />
        </div>

        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-between">
          {bundle ? <BundleDeleteButton bundleID={bundle.id} /> : <span />}
          <Button className="touch-target" disabled={pending} type="submit">
            {pending ? "Saving…" : bundle ? "Save bundle" : "Create bundle"}
          </Button>
        </div>
      </form>
    </Form>
  );
}
