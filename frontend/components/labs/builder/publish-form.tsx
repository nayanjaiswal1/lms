"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Rocket } from "lucide-react";
import { toast } from "sonner";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { FormSwitchField } from "@/components/ui/form-switch-field";
import { publishBuildAction } from "@/lib/labs/builder/actions";
import ROUTES from "@/lib/routes";

const PublishSchema = z.object({
  sectionId: z.string().min(1, "Choose a section"),
  isRequired: z.boolean(),
});
type PublishValues = z.infer<typeof PublishSchema>;

interface PublishFormProps {
  buildId: string;
  courseId: string;
  courseSlug: string;
  sectionOptions: { label: string; value: string }[];
  defaultSectionId: string;
}

export function PublishForm({ buildId, courseId, courseSlug, sectionOptions, defaultSectionId }: PublishFormProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const form = useForm<PublishValues>({
    resolver: zodResolver(PublishSchema),
    defaultValues: { sectionId: defaultSectionId, isRequired: true },
  });

  const onSubmit = (values: PublishValues) =>
    startTransition(async () => {
      const res = await publishBuildAction(buildId, { courseId, ...values });
      if (!res.ok || !res.data) {
        toast.error(res.error ?? "Could not publish the lab.");
        return;
      }
      toast.success(res.data.unchanged ? "This build is already published there." : `Published as version ${res.data.version}.`);
      router.push(ROUTES.courseEdit(courseSlug));
    });

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormSelectField control={form.control} label="Section" name="sectionId" options={sectionOptions} placeholder="Choose a section" />
        <FormSwitchField
          control={form.control}
          description="Students must complete required labs to finish the section."
          label="Required"
          name="isRequired"
        />
        <Button className="self-start" disabled={pending} type="submit">
          <Rocket aria-hidden className="h-4 w-4" />
          Publish
        </Button>
      </form>
    </Form>
  );
}
