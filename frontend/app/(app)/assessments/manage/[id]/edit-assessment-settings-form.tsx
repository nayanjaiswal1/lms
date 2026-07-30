"use client";

import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { FileText, Timer, SlidersHorizontal, ShieldAlert, Gauge, Lock } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { SectionHeader, ToggleRow } from "@/components/assessments/assessment-form-fields";
import { updateAssessmentAction } from "@/app/(app)/assessments/manage/actions";
import {
  AssessmentConfigSchema,
  ASSESSMENT_MODE_OPTIONS,
  FULLSCREEN_EXIT_OPTIONS,
  SETTING_TOGGLES,
  PROCTOR_TOGGLES,
  modeFromProctoring,
  buildProctoringPayload,
  type AssessmentConfigFormData,
} from "@/lib/assessments/config-schema";
import { cn } from "@/lib/utils";
import type { Assessment } from "@/lib/assessments/types";

interface EditAssessmentSettingsFormProps {
  assessment: Assessment;
}

export function EditAssessmentSettingsForm({ assessment }: EditAssessmentSettingsFormProps) {
  const router = useRouter();
  const p = assessment.proctoring;
  const form = useForm<AssessmentConfigFormData>({
    resolver: zodResolver(AssessmentConfigSchema),
    defaultValues: {
      mode: modeFromProctoring(p),
      title: assessment.title,
      description: assessment.description ?? "",
      duration_minutes: String(assessment.duration_minutes),
      pass_percentage: String(assessment.pass_percentage),
      max_attempts: String(assessment.max_attempts),
      shuffle_questions: assessment.shuffle_questions,
      shuffle_options: assessment.shuffle_options,
      allow_backtrack: assessment.allow_backtrack,
      show_results: assessment.show_results,
      require_fullscreen: p.require_fullscreen,
      fullscreen_exit_action: p.fullscreen_exit_action,
      block_copy_paste: p.block_copy_paste,
      block_right_click: p.block_right_click,
      block_devtools: p.block_devtools,
      max_tab_switches: String(p.max_tab_switches),
      max_focus_loss: String(p.max_focus_loss),
      auto_submit_on_violation: p.auto_submit_on_violation,
      require_camera: p.require_camera,
      allow_secondary_camera: p.allow_secondary_camera,
    },
  });
  const mode = form.watch("mode");
  const requireFullscreen = form.watch("require_fullscreen");
  const isProctored = mode === "proctored";
  // The backend only accepts this PATCH while status = 'draft' (see
  // repo_assessment.go UpdateAssessment) — changing timing/proctoring on a
  // test students are actively taking is deliberately blocked. Publish/status
  // moves live in the Questions tab, not here — this form only edits config.
  const isEditable = assessment.status === "draft";

  const onSubmit = async (data: AssessmentConfigFormData) => {
    const res = await updateAssessmentAction(assessment.id, {
      title: data.title,
      description: data.description,
      parent_type: assessment.parent_type,
      parent_id: assessment.parent_id,
      duration_minutes: Number(data.duration_minutes),
      pass_percentage: Number(data.pass_percentage),
      max_attempts: Number(data.max_attempts),
      shuffle_questions: data.shuffle_questions,
      shuffle_options: data.shuffle_options,
      allow_backtrack: data.allow_backtrack,
      show_results: data.show_results,
      proctoring: buildProctoringPayload(data),
    });
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Settings saved.");
    router.refresh();
  };

  return (
    <Form {...form}>
      <form className="flex flex-col gap-6" onSubmit={form.handleSubmit(onSubmit)}>
        {!isEditable && (
          <div className="flex items-start gap-3 rounded-lg border border-border bg-muted p-4">
            <Lock aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />
            <p className="text-sm text-muted-foreground">
              This assessment is <span className="font-medium text-foreground">{assessment.status}</span> — test
              configuration can only be changed while it&apos;s a draft, so timing and proctoring can&apos;t shift
              under students mid-attempt. Move it back to draft from the Questions tab to edit these settings.
            </p>
          </div>
        )}
        <fieldset className="flex flex-col gap-6" disabled={!isEditable}>
        <legend className="sr-only">Assessment configuration</legend>
        <section className="card-base p-6">
          <SectionHeader
            description="Decide how strict this test needs to be."
            icon={Gauge}
            title="Assessment type"
          />
          <FormField
            control={form.control}
            name="mode"
            render={({ field }) => (
              <FormItem>
                <FormControl>
                  <RadioGroup className="gap-3 sm:grid sm:grid-cols-2" value={field.value} onValueChange={field.onChange}>
                    {ASSESSMENT_MODE_OPTIONS.map((o) => (
                      <label
                        className={cn(
                          "flex cursor-pointer items-start gap-3 rounded-md border p-3 transition-colors duration-fast",
                          field.value === o.value ? "border-primary bg-primary/5" : "border-border bg-card",
                        )}
                        htmlFor={`mode-${o.value}`}
                        key={o.value}
                      >
                        <RadioGroupItem className="mt-0.5" id={`mode-${o.value}`} value={o.value} />
                        <span>
                          <span className="block text-sm font-medium text-foreground">{o.label}</span>
                          <span className="block text-xs text-muted-foreground">{o.description}</span>
                        </span>
                      </label>
                    ))}
                  </RadioGroup>
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        </section>

        <div className="columns-1 gap-6 lg:columns-2">
          <section className="card-base mb-6 break-inside-avoid p-6">
            <SectionHeader
              description="What the test is called and where it's used."
              icon={FileText}
              title="Basics"
            />
            <div className="form-stack">
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
            </div>
          </section>

          <section className="card-base mb-6 break-inside-avoid p-6">
            <SectionHeader
              description="How long students have and what it takes to pass."
              icon={Timer}
              title="Timing & scoring"
            />
            <div className="grid gap-4 sm:grid-cols-3">
              <FormInputField control={form.control} label="Duration (min)" name="duration_minutes" type="number" />
              <FormInputField control={form.control} label="Pass %" name="pass_percentage" type="number" />
              <FormInputField control={form.control} label="Max attempts" name="max_attempts" type="number" />
            </div>
          </section>

          <section className="card-base mb-6 break-inside-avoid p-6">
            <SectionHeader
              description="Question order and what students see during and after the attempt."
              icon={SlidersHorizontal}
              title="Test behavior"
            />
            <fieldset className="divide-y divide-border">
              <legend className="sr-only">Test behavior</legend>
              {SETTING_TOGGLES.map((t) => (
                <ToggleRow control={form.control} description={t.description} key={t.name} label={t.label} name={t.name} />
              ))}
            </fieldset>
          </section>

          {isProctored && (
          <section className="card-base mb-6 break-inside-avoid p-6">
            <SectionHeader
              description="Lock down the test environment and react to suspicious activity."
              icon={ShieldAlert}
              title="Anti-cheat & proctoring"
            />
            <fieldset className="divide-y divide-border">
              <legend className="sr-only">Anti-cheat & proctoring</legend>
              {PROCTOR_TOGGLES.map((t) => (
                <ToggleRow control={form.control} description={t.description} key={t.name} label={t.label} name={t.name} />
              ))}
            </fieldset>

            {requireFullscreen && (
              <FormField
                control={form.control}
                name="fullscreen_exit_action"
                render={({ field }) => (
                  <FormItem className="mt-4 border-t border-border pt-4">
                    <FormLabel>When a student exits fullscreen</FormLabel>
                    <FormControl>
                      <RadioGroup className="gap-2" value={field.value} onValueChange={field.onChange}>
                        {FULLSCREEN_EXIT_OPTIONS.map((o) => (
                          <label
                            className={cn(
                              "flex cursor-pointer items-start gap-3 rounded-md border p-3 transition-colors duration-fast",
                              field.value === o.value ? "border-primary bg-primary/5" : "border-border bg-card",
                            )}
                            htmlFor={`fullscreen-exit-${o.value}`}
                            key={o.value}
                          >
                            <RadioGroupItem className="mt-0.5" id={`fullscreen-exit-${o.value}`} value={o.value} />
                            <span>
                              <span className="block text-sm font-medium text-foreground">{o.label}</span>
                              <span className="block text-xs text-muted-foreground">{o.description}</span>
                            </span>
                          </label>
                        ))}
                      </RadioGroup>
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            )}

            <div className="mt-4 grid gap-4 sm:grid-cols-2">
              <FormInputField control={form.control} label="Max tab switches (0 = ∞)" name="max_tab_switches" type="number" />
              <FormInputField control={form.control} label="Max focus loss (0 = ∞)" name="max_focus_loss" type="number" />
            </div>
          </section>
          )}
        </div>
        </fieldset>

        {isEditable && (
          <div className="flex justify-end">
            <Button className="px-5 py-2.5" disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Saving…" : "Save changes"}
            </Button>
          </div>
        )}
      </form>
    </Form>
  );
}
