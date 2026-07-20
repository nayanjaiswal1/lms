"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { SKILL_LEVEL_OPTIONS } from "@/lib/constants";
import { createRoadmapAction } from "@/lib/roadmap/actions";
import ROUTES from "@/lib/routes";
import type { RoadmapProfileDefaults } from "@/lib/server/roadmap";

const RoadmapSchema = z.object({
  goal_description: z.string().min(1, "Describe your goal.").max(2000),
  target_role: z.string().max(200).optional(),
  skill_level: z.string().optional(),
  timeframe_weeks: z.string().optional(),
});

type RoadmapFormData = z.infer<typeof RoadmapSchema>;

interface NewRoadmapFormProps {
  defaults: RoadmapProfileDefaults | null;
}

export function NewRoadmapForm({ defaults }: NewRoadmapFormProps) {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | undefined>();

  const form = useForm<RoadmapFormData>({
    resolver: zodResolver(RoadmapSchema),
    defaultValues: {
      goal_description: defaults?.career_goal ?? defaults?.learning_goal ?? "",
      target_role: "",
      skill_level: defaults?.skill_level ?? "",
      timeframe_weeks: "",
    },
  });

  async function onSubmit(data: RoadmapFormData) {
    setServerError(undefined);
    const weeks = data.timeframe_weeks ? parseInt(data.timeframe_weeks, 10) : undefined;
    const result = await createRoadmapAction({
      goal_description: data.goal_description,
      target_role: data.target_role || undefined,
      skill_level: data.skill_level || undefined,
      timeframe_weeks: weeks && !isNaN(weeks) ? weeks : undefined,
    });
    if (!result.ok || !result.data) {
      setServerError(result.error ?? "Something went wrong.");
      return;
    }
    router.push(ROUTES.roadmap(result.data.id));
  }

  const pending = form.formState.isSubmitting;

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="goal_description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>What do you want to achieve?</FormLabel>
              <FormControl>
                <Textarea
                  className="resize-none text-sm"
                  disabled={pending}
                  placeholder="e.g. Become a job-ready backend engineer in 12 weeks — Go, PostgreSQL, and enough DSA to pass interviews."
                  rows={5}
                  {...field}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormInputField
          control={form.control}
          disabled={pending}
          label="Target role (optional)"
          name="target_role"
          placeholder="e.g. Backend Engineer"
        />

        <div className="stack-sm">
          <FormSelectField
            control={form.control}
            label="Current skill level"
            name="skill_level"
            options={SKILL_LEVEL_OPTIONS}
            placeholder="Select a level"
          />
          <FormInputField
            control={form.control}
            disabled={pending}
            label="Timeframe (weeks, optional)"
            max={104}
            min={1}
            name="timeframe_weeks"
            placeholder="e.g. 12"
            type="number"
          />
        </div>

        {serverError && (
          <p className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">{serverError}</p>
        )}

        <Button className="w-full sm:w-auto" disabled={pending} type="submit">
          {pending ? "Starting generation…" : "Generate my roadmap"}
        </Button>
      </form>
    </Form>
  );
}
