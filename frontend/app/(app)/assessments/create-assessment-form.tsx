"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { FileText, Timer, SlidersHorizontal, ShieldAlert, Gauge } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { SectionHeader, ToggleRow } from "@/components/assessments/assessment-form-fields";
import { createAssessmentAction } from "@/app/(app)/assessments/actions";
import {
  AssessmentConfigSchema,
  ASSESSMENT_MODE_OPTIONS,
  ASSESSMENT_SCOPE_OPTIONS,
  FULLSCREEN_EXIT_OPTIONS,
  SETTING_TOGGLES,
  PROCTOR_TOGGLES,
  buildProctoringPayload,
  type AssessmentConfigFormData,
} from "@/lib/assessments/config-schema";
import { ASSESSMENT_PARENT_TYPE, type AssessmentParentType } from "@/lib/constants";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

export function CreateAssessmentForm() {
  const router = useRouter();
  // Scope isn't part of the shared config schema (the edit form never exposes
  // it — parent_type is immutable after creation), so it stays outside
  // react-hook-form as one plain field, same as the other two-option radios.
  const [parentType, setParentType] = useState<AssessmentParentType>(ASSESSMENT_PARENT_TYPE.STANDALONE);
  const form = useForm<AssessmentConfigFormData>({
    resolver: zodResolver(AssessmentConfigSchema),
    defaultValues: {
      mode: "proctored",
      title: "",
      description: "",
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
  const mode = form.watch("mode");
  const requireFullscreen = form.watch("require_fullscreen");
  const isProctored = mode === "proctored";

  const onSubmit = async (data: AssessmentConfigFormData) => {
    const res = await createAssessmentAction({
      title: data.title,
      description: data.description,
      parent_type: parentType,
      duration_minutes: Number(data.duration_minutes),
      pass_percentage: Number(data.pass_percentage),
      max_attempts: Number(data.max_attempts),
      shuffle_questions: data.shuffle_questions,
      shuffle_options: data.shuffle_options,
      allow_backtrack: data.allow_backtrack,
      show_results: data.show_results,
      proctoring: buildProctoringPayload(data),
    });
    if (res.error || !res.id) {
      toast.error(res.error ?? "Could not create the assessment.");
      return;
    }
    toast.success("Assessment created. Add questions next.");
    router.push(ROUTES.assessmentEdit(res.id));
  };

  return (
    <Form {...form}>
      <form className="flex flex-col gap-6" onSubmit={form.handleSubmit(onSubmit)}>
        <section className="card-base p-6">
          <SectionHeader
            description="Who it's for and how strict it needs to be."
            icon={Gauge}
            title="Assessment type"
          />
          <div className="flex flex-col gap-4">
            <div>
              <p className="mb-2 text-sm font-medium text-foreground">Scope</p>
              <RadioGroup
                className="gap-3 sm:grid sm:grid-cols-2"
                value={parentType}
                onValueChange={(v) => setParentType(v as AssessmentParentType)}
              >
                {ASSESSMENT_SCOPE_OPTIONS.map((o) => (
                  <label
                    className={cn(
                      "flex cursor-pointer items-start gap-3 rounded-md border p-3 transition-colors duration-fast",
                      parentType === o.value ? "border-primary bg-primary/5" : "border-border bg-card",
                    )}
                    htmlFor={`scope-${o.value}`}
                    key={o.value}
                  >
                    <RadioGroupItem className="mt-0.5" id={`scope-${o.value}`} value={o.value} />
                    <span>
                      <span className="block text-sm font-medium text-foreground">{o.label}</span>
                      <span className="block text-xs text-muted-foreground">{o.description}</span>
                    </span>
                  </label>
                ))}
              </RadioGroup>
            </div>

            <FormField
              control={form.control}
              name="mode"
              render={({ field }) => (
                <FormItem>
                  <p className="mb-2 text-sm font-medium text-foreground">Strictness</p>
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
          </div>
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

        <Button className="self-end px-5 py-2.5" disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Creating…" : "Create assessment"}
        </Button>
      </form>
    </Form>
  );
}
