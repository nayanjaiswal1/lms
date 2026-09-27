"use client";

import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage, FormDescription } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { Input } from "@/components/ui/input";
import { TagInput } from "@/components/ui/tag-input";
import { createWorkspaceAction } from "@/lib/workspace/actions";
import ROUTES from "@/lib/routes";

// datetime-local works in local time with no timezone suffix; the API
// exchanges UTC ISO strings — same conversion as create-requirement-form.tsx.
function localInputToIso(value: string): string | null {
  return value ? new Date(value).toISOString() : null;
}

const Schema = z
  .object({
    title: z.string().min(3, "Title must be at least 3 characters.").max(200),
    requirement: z.string().min(50, "Give the team at least 50 characters of requirement detail.").max(20000),
    skills: z.array(z.string().max(40)).max(15, "Up to 15 skills."),
    team_size_min: z.string().refine((v) => Number(v) >= 2, "Minimum team size is 2 (so a brief always has a second approver)."),
    team_size_max: z.string().refine((v) => Number(v) <= 50, "Maximum team size is 50."),
    interest_deadline: z.string(),
    key_prefix: z
      .string()
      .regex(/^[A-Z]{2,6}$/, "2–6 uppercase letters, e.g. PAY.")
      .optional()
      .or(z.literal("")),
  })
  .refine((v) => Number(v.team_size_max) >= Number(v.team_size_min), {
    message: "Max team size must be at least the min team size.",
    path: ["team_size_max"],
  });
type FormData = z.infer<typeof Schema>;

// Server default = first letters of the title, upper, padded to 2–6 — mirrors
// service_project.go's own fallback so the placeholder previews what an empty
// field will resolve to, without duplicating validation client-side.
function suggestKeyPrefix(title: string): string {
  const letters = title.replace(/[^a-zA-Z]/g, "").toUpperCase();
  return letters.slice(0, 6).padEnd(2, "X");
}

export function CreateProjectForm() {
  const router = useRouter();
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      title: "",
      requirement: "",
      skills: [],
      team_size_min: "2",
      team_size_max: "5",
      interest_deadline: "",
      key_prefix: "",
    },
  });

  const titleValue = form.watch("title");

  const onSubmit = async (data: FormData) => {
    const result = await createWorkspaceAction({
      title: data.title,
      requirement: data.requirement,
      skills: data.skills,
      team_size_min: Number(data.team_size_min),
      team_size_max: Number(data.team_size_max),
      interest_deadline: localInputToIso(data.interest_deadline),
      key_prefix: data.key_prefix || suggestKeyPrefix(data.title),
    });
    if (result.error || !result.data) {
      toast.error(result.error ?? "Could not create the workspace.");
      return;
    }
    toast.success("Workspace created.");
    router.push(ROUTES.workspace(result.data.id));
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Title" name="title" placeholder="Real-time collaborative whiteboard" />

        <FormTextareaField
          control={form.control}
          description="At least 50 characters — this becomes v1 of the requirement history."
          label="Requirement"
          name="requirement"
          placeholder="What the project is, what the team will build, and how success is judged…"
          rows={8}
        />

        <FormField
          control={form.control}
          name="skills"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Skills</FormLabel>
              <FormControl>
                <TagInput placeholder="Add a skill and press Enter…" value={field.value} onChange={field.onChange} />
              </FormControl>
              <FormDescription>Up to 15 — shown on the public share page and used for interest ranking.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="grid gap-4 sm:grid-cols-2">
          <FormInputField control={form.control} label="Min team size" name="team_size_min" type="number" />
          <FormInputField control={form.control} label="Max team size" name="team_size_max" type="number" />
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <FormField
            control={form.control}
            name="interest_deadline"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Interest deadline (optional)</FormLabel>
                <FormControl>
                  <Input type="datetime-local" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormInputField
            control={form.control}
            description={`Leave blank to use ${suggestKeyPrefix(titleValue || "")}.`}
            label="Ticket key prefix (optional)"
            name="key_prefix"
            placeholder={suggestKeyPrefix(titleValue || "") || "e.g. PAY"}
          />
        </div>

        <Button className="self-end px-5 py-2.5" disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Creating…" : "Create workspace"}
        </Button>
      </form>
    </Form>
  );
}
