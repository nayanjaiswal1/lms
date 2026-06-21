"use client";

import { useState, useTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { ArrowRight, ArrowLeft } from "lucide-react";

import { saveOnboardingAction } from "@/app/onboarding/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  SelectionCard,
  StepIndicator,
  TopicGrid,
  LEARNING_GOAL_OPTIONS,
  ROLE_SUGGESTIONS,
  TIME_OPTIONS,
  SKILL_OPTIONS,
  TOPICS,
} from "@/app/onboarding/onboarding-parts";

// ─── Schema ───────────────────────────────────────────────────────────────────

const schema = z.object({
  learning_goal: z.enum(["get_promotion", "switch_careers", "build_project", "stay_current", "compliance"]),
  job_title: z.string().min(1, "Please tell us your role or background").max(100),
  topics_interest: z.array(z.string()).min(1, "Select at least one topic"),
  weekly_time_commitment: z.enum(["1_2_hrs", "3_5_hrs", "5_10_hrs", "10_plus_hrs"]),
  skill_level: z.enum(["beginner", "some_experience", "intermediate", "advanced"]),
});

type FormData = z.infer<typeof schema>;

const TOTAL_STEPS = 5;

// ─── Wizard ───────────────────────────────────────────────────────────────────

export function OnboardingWizard() {
  const [step, setStep] = useState(0);
  const [isPending, startTransition] = useTransition();

  const form = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { topics_interest: [] },
  });

  const watchedGoal = form.watch("learning_goal");
  const watchedTopics = form.watch("topics_interest");
  const watchedTime = form.watch("weekly_time_commitment");
  const watchedSkill = form.watch("skill_level");

  function handleFinish(data: FormData) {
    startTransition(async () => {
      const result = await saveOnboardingAction({ ...data, completed: true });
      if (result?.error) form.setError("root", { message: result.error });
    });
  }

  function handleSkip() {
    startTransition(async () => {
      const result = await saveOnboardingAction({ completed: true });
      if (result?.error) form.setError("root", { message: result.error });
    });
  }

  async function handleContinue() {
    const stepFields: Record<number, (keyof FormData)[]> = {
      0: ["learning_goal"],
      1: ["job_title"],
      2: ["topics_interest"],
      3: ["weekly_time_commitment"],
    };
    const fields = stepFields[step];
    if (fields) {
      const valid = await form.trigger(fields);
      if (!valid) return;
    }
    if (step === 4) {
      await form.handleSubmit(handleFinish)();
    } else {
      setStep((s) => s + 1);
    }
  }

  function toggleTopic(value: string) {
    const current = form.getValues("topics_interest");
    const next = current.includes(value) ? current.filter((v) => v !== value) : [...current, value];
    form.setValue("topics_interest", next, { shouldValidate: true });
  }

  const firstTopicLabel = TOPICS.find((t) => watchedTopics?.[0] === t.value)?.label;
  const skillSubtitle = firstTopicLabel
    ? `In ${firstTopicLabel} and your other chosen areas`
    : "Rate your overall level across your chosen topics";

  return (
    <div className="flex min-h-dvh flex-col items-center justify-center px-4 py-12 sm:px-6">
      <div className="flex w-full max-w-lg flex-col gap-8">
        <StepIndicator current={step} total={TOTAL_STEPS} />

        {/* Step 0 — Learning Goal */}
        {step === 0 && (
          <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-2">
              <h1>What do you want to achieve?</h1>
              <p className="text-muted-foreground">We'll build your personalized path around this goal</p>
            </div>
            <div className="flex flex-col gap-3">
              {LEARNING_GOAL_OPTIONS.map((opt) => (
                <SelectionCard
                  key={opt.value}
                  selected={watchedGoal === opt.value}
                  onClick={() => form.setValue("learning_goal", opt.value, { shouldValidate: true })}
                  title={opt.title}
                  subtitle={opt.subtitle}
                />
              ))}
            </div>
            {form.formState.errors.learning_goal && (
              <p className="text-sm text-destructive">{form.formState.errors.learning_goal.message}</p>
            )}
            <div className="flex items-center justify-between gap-4">
              <button
                type="button"
                onClick={handleSkip}
                disabled={isPending}
                className="text-sm text-muted-foreground underline-offset-4 hover:underline disabled:opacity-50"
              >
                Skip setup →
              </button>
              <Button onClick={handleContinue} disabled={!watchedGoal || isPending} className="gap-2">
                Continue <ArrowRight aria-hidden className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}

        {/* Step 1 — Background */}
        {step === 1 && (
          <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-2">
              <h1>What's your current role or background?</h1>
              <p className="text-muted-foreground">Helps us skip content you already know</p>
            </div>
            <div className="flex flex-col gap-3">
              <Input
                {...form.register("job_title")}
                placeholder="e.g. Software Engineer, Student, Designer…"
                maxLength={100}
                aria-invalid={!!form.formState.errors.job_title}
              />
              {form.formState.errors.job_title && (
                <p className="text-sm text-destructive">{form.formState.errors.job_title.message}</p>
              )}
              <div className="flex flex-wrap gap-2">
                {ROLE_SUGGESTIONS.map((role) => (
                  <button
                    key={role}
                    type="button"
                    onClick={() => form.setValue("job_title", role, { shouldValidate: true })}
                    className="rounded-full border border-border px-3 py-1 text-xs text-muted-foreground transition-colors duration-normal hover:border-primary hover:text-primary"
                  >
                    {role}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex items-center justify-between gap-4">
              <Button variant="ghost" onClick={() => setStep(0)} disabled={isPending} className="gap-2">
                <ArrowLeft aria-hidden className="h-4 w-4" /> Back
              </Button>
              <Button onClick={handleContinue} disabled={isPending} className="gap-2">
                Continue <ArrowRight aria-hidden className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}

        {/* Step 2 — Topics */}
        {step === 2 && (
          <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-2">
              <h1>What do you want to learn?</h1>
              <p className="text-muted-foreground">Select all that apply — we'll build around your choices</p>
            </div>
            <TopicGrid selected={watchedTopics ?? []} onToggle={toggleTopic} />
            {form.formState.errors.topics_interest && (
              <p className="text-sm text-destructive">{form.formState.errors.topics_interest.message}</p>
            )}
            <div className="flex items-center justify-between gap-4">
              <Button variant="ghost" onClick={() => setStep(1)} disabled={isPending} className="gap-2">
                <ArrowLeft aria-hidden className="h-4 w-4" /> Back
              </Button>
              <Button onClick={handleContinue} disabled={!watchedTopics?.length || isPending} className="gap-2">
                Continue <ArrowRight aria-hidden className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}

        {/* Step 3 — Time Commitment */}
        {step === 3 && (
          <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-2">
              <h1>How much time can you commit each week?</h1>
              <p className="text-muted-foreground">We'll pace your learning path to match your schedule</p>
            </div>
            <div className="flex flex-col gap-3">
              {TIME_OPTIONS.map((opt) => (
                <SelectionCard
                  key={opt.value}
                  selected={watchedTime === opt.value}
                  onClick={() => form.setValue("weekly_time_commitment", opt.value, { shouldValidate: true })}
                  title={opt.title}
                  subtitle={opt.subtitle}
                />
              ))}
            </div>
            {form.formState.errors.weekly_time_commitment && (
              <p className="text-sm text-destructive">{form.formState.errors.weekly_time_commitment.message}</p>
            )}
            <div className="flex items-center justify-between gap-4">
              <Button variant="ghost" onClick={() => setStep(2)} disabled={isPending} className="gap-2">
                <ArrowLeft aria-hidden className="h-4 w-4" /> Back
              </Button>
              <Button onClick={handleContinue} disabled={!watchedTime || isPending} className="gap-2">
                Continue <ArrowRight aria-hidden className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}

        {/* Step 4 — Skill Level */}
        {step === 4 && (
          <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-2">
              <h1>What's your current level?</h1>
              <p className="text-muted-foreground">{skillSubtitle}</p>
            </div>
            <div className="flex flex-col gap-3">
              {SKILL_OPTIONS.map((opt) => (
                <SelectionCard
                  key={opt.value}
                  selected={watchedSkill === opt.value}
                  onClick={() => form.setValue("skill_level", opt.value, { shouldValidate: true })}
                  title={opt.title}
                  subtitle={opt.subtitle}
                />
              ))}
            </div>
            {form.formState.errors.skill_level && (
              <p className="text-sm text-destructive">{form.formState.errors.skill_level.message}</p>
            )}
            {form.formState.errors.root && (
              <p className="text-sm text-destructive">{form.formState.errors.root.message}</p>
            )}
            <div className="flex items-center justify-between gap-4">
              <Button variant="ghost" onClick={() => setStep(3)} disabled={isPending} className="gap-2">
                <ArrowLeft aria-hidden className="h-4 w-4" /> Back
              </Button>
              <Button onClick={handleContinue} disabled={!watchedSkill || isPending} className="gap-2">
                Get started <ArrowRight aria-hidden className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
