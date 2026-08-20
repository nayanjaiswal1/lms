"use client";

import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { createRequirementAction } from "@/app/(app)/projects/actions";
import ROUTES from "@/lib/routes";

// datetime-local inputs work in local time with no timezone suffix; the API
// exchanges UTC ISO strings — same edge conversion as create-assignment-form.tsx.
function localInputToIso(value: string): string {
  return new Date(value).toISOString();
}

const Schema = z
  .object({
    title: z.string().min(2, "Title is too short."),
    brief: z.string().min(10, "Give students enough detail to decide whether to apply."),
    required_skills: z.string(),
    team_size_min: z.string().refine((v) => Number(v) >= 1, "Enter at least 1."),
    team_size_max: z.string().refine((v) => Number(v) >= 1, "Enter at least 1."),
    application_deadline: z.string().min(1, "An application deadline is required."),
  })
  .refine((v) => Number(v.team_size_max) >= Number(v.team_size_min), {
    message: "Max team size must be at least the min team size.",
    path: ["team_size_max"],
  });
type FormData = z.infer<typeof Schema>;

export function CreateRequirementForm() {
  const router = useRouter();
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      title: "",
      brief: "",
      required_skills: "",
      team_size_min: "2",
      team_size_max: "4",
      application_deadline: "",
    },
  });

  const onSubmit = async (data: FormData) => {
    const res = await createRequirementAction({
      title: data.title,
      brief: data.brief,
      required_skills: data.required_skills
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
      team_size_min: Number(data.team_size_min),
      team_size_max: Number(data.team_size_max),
      application_deadline: localInputToIso(data.application_deadline),
    });
    if (res.error || !res.data) {
      toast.error(res.error ?? "Could not create the requirement.");
      return;
    }
    toast.success("Requirement created as a draft. Publish it to open the board.");
    router.push(ROUTES.projectRequirement(res.data.id));
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Title" name="title" placeholder="Real-time collaborative whiteboard" />

        <FormField
          control={form.control}
          name="brief"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Brief</FormLabel>
              <FormControl>
                <Textarea placeholder="What the project is, what students will build, and what a strong application looks like…" rows={6} {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormInputField
          control={form.control}
          description="Comma-separated — shown on the board and used for AI shortlisting in a later phase."
          label="Required skills"
          name="required_skills"
          placeholder="React, WebSockets, PostgreSQL"
        />

        <div className="grid gap-4 sm:grid-cols-2">
          <FormInputField control={form.control} label="Min team size" name="team_size_min" type="number" />
          <FormInputField control={form.control} label="Max team size" name="team_size_max" type="number" />
        </div>

        <FormField
          control={form.control}
          name="application_deadline"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Application deadline</FormLabel>
              <FormControl>
                <Input type="datetime-local" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button className="self-end px-5 py-2.5" disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Creating…" : "Create requirement"}
        </Button>
      </form>
    </Form>
  );
}
