"use client";

import { useRouter } from "next/navigation";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ASSESSMENT_PARENT_TYPE_OPTIONS } from "@/lib/constants";
import { createAssessmentAction } from "@/app/(app)/assessments/manage/actions";
import ROUTES from "@/lib/routes";

const numeric = z.string().refine((v) => v !== "" && !Number.isNaN(Number(v)), "Enter a number.");

const FULLSCREEN_EXIT_OPTIONS = [
  { value: "pause",       label: "Pause timer",        description: "Freeze the clock; student must return to fullscreen to resume" },
  { value: "continue",    label: "Keep timer running",  description: "Hide questions but keep the clock running — no free breaks" },
  { value: "auto_submit", label: "Auto-submit",         description: "Immediately submit the attempt when fullscreen is exited" },
] as const;

const Schema = z.object({
  title: z.string().min(3, "Title is too short."),
  description: z.string().optional(),
  parent_type: z.string(),
  duration_minutes: numeric,
  pass_percentage: numeric,
  max_attempts: numeric,
  shuffle_questions: z.boolean(),
  shuffle_options: z.boolean(),
  allow_backtrack: z.boolean(),
  show_results: z.boolean(),
  require_fullscreen: z.boolean(),
  fullscreen_exit_action: z.enum(["pause", "continue", "auto_submit"]),
  block_copy_paste: z.boolean(),
  block_right_click: z.boolean(),
  block_devtools: z.boolean(),
  max_tab_switches: numeric,
  max_focus_loss: numeric,
  auto_submit_on_violation: z.boolean(),
  require_camera: z.boolean(),
  allow_secondary_camera: z.boolean(),
});
type FormData = z.infer<typeof Schema>;

const SETTING_TOGGLES: { name: keyof FormData; label: string }[] = [
  { name: "shuffle_questions", label: "Shuffle questions" },
  { name: "shuffle_options", label: "Shuffle options" },
  { name: "allow_backtrack", label: "Allow going back" },
  { name: "show_results", label: "Show results to student" },
];

const PROCTOR_TOGGLES: { name: keyof FormData; label: string }[] = [
  { name: "require_fullscreen", label: "Require fullscreen" },
  { name: "block_copy_paste", label: "Block copy / paste" },
  { name: "block_right_click", label: "Block right-click" },
  { name: "block_devtools", label: "Block dev tools" },
  { name: "auto_submit_on_violation", label: "Auto-submit on violation" },
  { name: "require_camera", label: "Require camera (webcam preflight)" },
  { name: "allow_secondary_camera", label: "Allow secondary phone camera" },
];

export function CreateAssessmentForm() {
  const router = useRouter();
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      title: "",
      description: "",
      parent_type: "standalone",
      duration_minutes: "30",
      pass_percentage: "40",
      max_attempts: "1",
      shuffle_questions: false,
      shuffle_options: false,
      allow_backtrack: true,
      show_results: true,
      require_fullscreen: true,
      fullscreen_exit_action: "pause",
      block_copy_paste: true,
      block_right_click: true,
      block_devtools: true,
      max_tab_switches: "3",
      max_focus_loss: "5",
      auto_submit_on_violation: true,
      require_camera: true,
      allow_secondary_camera: true,
    },
  });
  const requireFullscreen = form.watch("require_fullscreen");

  const onSubmit = async (data: FormData) => {
    const res = await createAssessmentAction({
      title: data.title,
      description: data.description,
      parent_type: data.parent_type,
      duration_minutes: Number(data.duration_minutes),
      pass_percentage: Number(data.pass_percentage),
      max_attempts: Number(data.max_attempts),
      shuffle_questions: data.shuffle_questions,
      shuffle_options: data.shuffle_options,
      allow_backtrack: data.allow_backtrack,
      show_results: data.show_results,
      proctoring: {
        require_fullscreen: data.require_fullscreen,
        fullscreen_exit_action: data.fullscreen_exit_action,
        block_copy_paste: data.block_copy_paste,
        block_right_click: data.block_right_click,
        block_devtools: data.block_devtools,
        max_tab_switches: Number(data.max_tab_switches),
        max_focus_loss: Number(data.max_focus_loss),
        auto_submit_on_violation: data.auto_submit_on_violation,
        heartbeat_seconds: 15,
        require_camera: data.require_camera,
        allow_secondary_camera: data.allow_secondary_camera,
      },
    });
    if (res.error || !res.id) {
      toast.error(res.error ?? "Could not create the assessment.");
      return;
    }
    toast.success("Assessment created. Add questions next.");
    router.push(ROUTES.manageAssessment(res.id));
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Title" name="title" placeholder="Midterm — Data Structures" />

        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Description</FormLabel>
              <FormControl>
                <Textarea placeholder="Optional summary shown to students…" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="parent_type"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Attach to</FormLabel>
              <Select value={field.value} onValueChange={field.onChange}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  {ASSESSMENT_PARENT_TYPE_OPTIONS.map((o) => (
                    <SelectItem key={o.value} value={o.value}>
                      {o.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="grid gap-4 sm:grid-cols-3">
          <FormInputField control={form.control} label="Duration (min)" name="duration_minutes" type="number" />
          <FormInputField control={form.control} label="Pass %" name="pass_percentage" type="number" />
          <FormInputField control={form.control} label="Max attempts" name="max_attempts" type="number" />
        </div>

        <fieldset className="flex flex-col gap-3">
          <legend className="mb-2 text-sm font-semibold">Test settings</legend>
          {SETTING_TOGGLES.map((t) => (
            <ToggleRow control={form.control} key={t.name} label={t.label} name={t.name} />
          ))}
        </fieldset>

        <fieldset className="flex flex-col gap-3">
          <legend className="mb-2 text-sm font-semibold">Anti-cheat / proctoring</legend>
          {PROCTOR_TOGGLES.map((t) => (
            <ToggleRow control={form.control} key={t.name} label={t.label} name={t.name} />
          ))}

          {requireFullscreen && (
            <FormField
              control={form.control}
              name="fullscreen_exit_action"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>When student exits fullscreen</FormLabel>
                  <Select value={field.value} onValueChange={field.onChange}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {FULLSCREEN_EXIT_OPTIONS.map((o) => (
                        <SelectItem key={o.value} value={o.value}>
                          <span className="font-medium">{o.label}</span>
                          <span className="ml-2 text-xs text-muted-foreground">{o.description}</span>
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
          )}

          <div className="grid gap-4 sm:grid-cols-2">
            <FormInputField control={form.control} label="Max tab switches (0 = ∞)" name="max_tab_switches" type="number" />
            <FormInputField control={form.control} label="Max focus loss (0 = ∞)" name="max_focus_loss" type="number" />
          </div>
        </fieldset>

        <Button disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Creating…" : "Create assessment"}
        </Button>
      </form>
    </Form>
  );
}

function ToggleRow({
  control,
  name,
  label,
}: {
  control: ReturnType<typeof useForm<FormData>>["control"];
  name: keyof FormData;
  label: string;
}) {
  return (
    <Label className="flex items-center gap-3 font-normal">
      <Controller
        control={control}
        name={name}
        render={({ field }) => (
          <Checkbox
            aria-label={label}
            checked={Boolean(field.value)}
            onCheckedChange={field.onChange}
          />
        )}
      />
      {label}
    </Label>
  );
}
