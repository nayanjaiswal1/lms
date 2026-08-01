"use client";

import { useTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { ArrowRight, CheckCircle2, Circle, Flame } from "lucide-react";

import { saveOnboardingAction } from "@/app/onboarding/actions";
import { Button } from "@/components/ui/button";
import { BrandMark } from "@/components/shared/brand-mark";
import { ThemeToggle } from "@/components/shared/theme-toggle";
import { SelectionCard, LEARNING_GOAL_OPTIONS, SKILL_OPTIONS } from "@/app/onboarding/onboarding-parts";
import { cn } from "@/lib/utils";

// ─── Schema ───────────────────────────────────────────────────────────────────
// Only fields an existing feature actually reads back (roadmap-creation defaults)
// are asked here — everything else can be collected later, in context, when a
// feature needs it.

const schema = z.object({
  learning_goal: z.enum(["get_promotion", "switch_careers", "build_project", "stay_current", "compliance"]),
  skill_level: z.enum(["beginner", "some_experience", "intermediate", "advanced"]),
});

type FormData = z.infer<typeof schema>;

// ─── StatusPill ───────────────────────────────────────────────────────────────

function StatusPill({ label, done }: { label: string; done: boolean }) {
  const Icon = done ? CheckCircle2 : Circle;
  return (
    <span className={cn("flex items-center gap-1.5 text-xs font-medium", done ? "text-primary" : "text-muted-foreground")}>
      <Icon aria-hidden className="h-3.5 w-3.5" />
      {label}
    </span>
  );
}

// ─── Wizard ───────────────────────────────────────────────────────────────────

export function OnboardingWizard() {
  const [isPending, startTransition] = useTransition();

  const form = useForm<FormData>({ resolver: zodResolver(schema) });

  const watchedGoal = form.watch("learning_goal");
  const watchedSkill = form.watch("skill_level");

  function handleFinish(data: FormData) {
    startTransition(async () => {
      const result = await saveOnboardingAction({ ...data, completed: true });
      if (result?.error) toast.error(result.error);
    });
  }

  function handleSkip() {
    startTransition(async () => {
      const result = await saveOnboardingAction({ completed: true });
      if (result?.error) toast.error(result.error);
    });
  }

  return (
    <div className="flex min-h-dvh flex-col">
      {/* overflow-x-hidden is required: overflow-y-auto forces overflow-x from
          `visible` to `auto`, so the bleeding decorative flame below would
          otherwise open a horizontal scrollbar on every viewport. */}
      <div className="relative flex flex-1 flex-col items-center overflow-y-auto overflow-x-hidden px-4 pb-4 pt-6 sm:px-6">
        {/* Decorative forge flame — same signature mark used on the auth pages */}
        <Flame aria-hidden className="pointer-events-none absolute -right-10 -top-10 h-56 w-56 text-primary/5 sm:h-72 sm:w-72" />

        <div className="relative flex w-full max-w-3xl flex-col gap-8">
          <header className="relative flex items-center justify-between">
            <BrandMark />
            <ThemeToggle />
          </header>

          <div className="relative flex flex-col gap-3">
            <div className="flex flex-col gap-1">
              <h1>Let&apos;s forge your path</h1>
              <p className="text-sm text-muted-foreground">
                Two questions — we&apos;ll shape your roadmap around the answers. Nothing else to fill in.
              </p>
            </div>
            <div className="flex items-center gap-4">
              <StatusPill label="Goal" done={!!watchedGoal} />
              <StatusPill label="Skill level" done={!!watchedSkill} />
            </div>
          </div>

          <div className="relative grid-responsive-2">
            <div className="flex flex-col gap-2">
              <span className="text-sm font-medium text-foreground">What do you want to achieve?</span>
              <div className="flex flex-col gap-2">
                {LEARNING_GOAL_OPTIONS.map((opt) => (
                  <SelectionCard
                    key={opt.value}
                    selected={watchedGoal === opt.value}
                    onClick={() => form.setValue("learning_goal", opt.value, { shouldValidate: true })}
                    title={opt.title}
                    subtitle={opt.subtitle}
                    icon={opt.icon}
                  />
                ))}
              </div>
              {form.formState.errors.learning_goal && (
                <p className="text-sm text-destructive">{form.formState.errors.learning_goal.message}</p>
              )}
            </div>

            <div className="flex flex-col gap-2">
              <span className="text-sm font-medium text-foreground">What&apos;s your current level?</span>
              <div className="flex flex-col gap-2">
                {SKILL_OPTIONS.map((opt) => (
                  <SelectionCard
                    key={opt.value}
                    selected={watchedSkill === opt.value}
                    onClick={() => form.setValue("skill_level", opt.value, { shouldValidate: true })}
                    title={opt.title}
                    subtitle={opt.subtitle}
                    icon={opt.icon}
                  />
                ))}
              </div>
              {form.formState.errors.skill_level && (
                <p className="text-sm text-destructive">{form.formState.errors.skill_level.message}</p>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Sticky action bar — always visible, independent of how tall the content is */}
      <div className="safe-bottom sticky bottom-0 border-t border-border bg-background/95 backdrop-blur">
        <div className="mx-auto flex w-full max-w-3xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
          <button
            type="button"
            onClick={handleSkip}
            disabled={isPending}
            className="text-sm text-muted-foreground underline-offset-4 hover:underline disabled:opacity-50"
          >
            Skip setup →
          </button>
          <Button
            onClick={form.handleSubmit(handleFinish)}
            disabled={!watchedGoal || !watchedSkill || isPending}
            className="gap-2"
          >
            Get started <ArrowRight aria-hidden className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </div>
  );
}
