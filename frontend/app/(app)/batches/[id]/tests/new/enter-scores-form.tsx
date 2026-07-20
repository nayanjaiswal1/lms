"use client";

import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import type { MemberProgress } from "@/lib/server/batches";
import type { Terminology } from "@/lib/terminology";
import { enterOfflineTestScoresAction } from "@/app/(app)/batches/actions";
import ROUTES from "@/lib/routes";

const Schema = z.object({
  test_name: z.string().min(1, "Test name is required.").max(200),
  test_date: z.string().min(1, "Date is required."),
  max_score: z.coerce.number().positive("Max score must be greater than 0."),
  scores: z.array(
    z.object({
      user_id: z.string(),
      name: z.string(),
      score: z.coerce.number().min(0, "Score can't be negative."),
    }),
  ),
});
type FormInput = z.input<typeof Schema>;
type FormData = z.output<typeof Schema>;

interface EnterScoresFormProps {
  batchId: string;
  roster: MemberProgress[];
  t: Terminology;
}

export function EnterScoresForm({ batchId, roster, t }: EnterScoresFormProps) {
  const router = useRouter();
  const form = useForm<FormInput, unknown, FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      test_name: "",
      test_date: new Date().toISOString().slice(0, 10),
      max_score: 100,
      scores: roster.map((s) => ({ user_id: s.user_id, name: s.name, score: 0 })),
    },
  });

  const onSubmit = async (data: FormData) => {
    const res = await enterOfflineTestScoresAction(batchId, {
      test_name: data.test_name,
      test_date: data.test_date,
      max_score: data.max_score,
      scores: data.scores.map((s) => ({ user_id: s.user_id, score: s.score })),
    });
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Scores saved.");
    router.push(`${ROUTES.batch(batchId)}/tests`);
  };

  if (roster.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">
        Add {t.studentPlural.toLowerCase()} to this {t.class_.toLowerCase()} before entering test scores.
      </p>
    );
  }

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <div className="stack-sm">
          <FormInputField control={form.control} label="Test name" name="test_name" placeholder="Unit Test 1 — Measurement" />
          <FormField
            control={form.control}
            name="test_date"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Date</FormLabel>
                <FormControl>
                  <Input type="date" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormInputField control={form.control} label="Max score" min={1} name="max_score" step="0.5" type="number" />
        </div>

        <div className="card-base p-4">
          <h3 className="text-sm font-medium text-foreground mb-3">Scores</h3>
          <div className="flex flex-col divide-y divide-border">
            {roster.map((s, i) => (
              <div className="flex items-center justify-between gap-4 py-2" key={s.user_id}>
                <div className="flex flex-col min-w-0">
                  <span className="truncate font-medium">{s.name}</span>
                  <span className="truncate text-xs text-muted-foreground">{s.email}</span>
                </div>
                <div className="w-24 flex-shrink-0">
                  <FormInputField
                    control={form.control}
                    label="Score"
                    min={0}
                    name={`scores.${i}.score`}
                    step="0.5"
                    type="number"
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        <Button className="self-start" disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Saving…" : "Save scores"}
        </Button>
      </form>
    </Form>
  );
}
