"use client";

import * as React from "react";
import { useForm, useFieldArray, Controller } from "react-hook-form";
import { toast } from "sonner";
import { Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { QUESTION_TYPE_OPTIONS, CODE_LANGUAGE_OPTIONS } from "@/lib/constants";
import { upsertFinalTestAction } from "@/lib/courses/actions";
import type { CertificateRule, FinalTestConfig } from "@/lib/server/courses";
import { CertificateRuleForm } from "@/components/courses/wizard/certificate-rule-form";

interface FormQuestion {
  id: string;
  type: "mcq" | "coding";
  points: number;
  // mcq
  prompt: string;
  multiple: boolean;
  explanation: string;
  options: { text: string; is_correct: boolean }[];
  // coding
  languages: string[];
  test_cases: { stdin: string; expected: string; hidden: boolean; weight: number }[];
}

interface FormData {
  time_limit_minutes: number;
  passing_score_percent: number;
  max_attempts: number;
  questions: FormQuestion[];
}

function makeQuestion(type: "mcq" | "coding" = "mcq"): FormQuestion {
  return {
    id: crypto.randomUUID(),
    type,
    points: 5,
    prompt: "",
    multiple: false,
    explanation: "",
    options: [{ text: "", is_correct: true }, { text: "", is_correct: false }],
    languages: ["python"],
    test_cases: [{ stdin: "", expected: "", hidden: false, weight: 1 }],
  };
}

function configToForm(config: FinalTestConfig | null | undefined): FormData {
  if (!config) {
    return { time_limit_minutes: 30, passing_score_percent: 70, max_attempts: 3, questions: [makeQuestion()] };
  }
  return {
    time_limit_minutes: config.time_limit_minutes,
    passing_score_percent: config.passing_score_percent,
    max_attempts: config.max_attempts,
    questions: config.questions.map((q) => ({
      id: q.id,
      type: q.type,
      points: q.points,
      prompt: q.mcq?.prompt ?? q.coding?.prompt ?? "",
      multiple: q.mcq?.multiple ?? false,
      explanation: q.mcq?.explanation ?? "",
      options: q.mcq?.options.map((o) => ({ text: o.text, is_correct: o.is_correct ?? false })) ?? [
        { text: "", is_correct: true }, { text: "", is_correct: false },
      ],
      languages: q.coding?.languages ?? ["python"],
      test_cases: q.coding?.test_cases.map((c) => ({ stdin: c.stdin, expected: c.expected, hidden: c.hidden, weight: c.weight })) ?? [
        { stdin: "", expected: "", hidden: false, weight: 1 },
      ],
    })),
  };
}

interface FinalTestTabProps {
  courseId: string;
  initial: FinalTestConfig | null;
  certificateRule: CertificateRule | null;
}

// Final Test is one-per-course and saved independently of the rest of the
// course wizard (its own PUT /api/courses/:id/final-test) — it doesn't need
// the multi-action diff-and-save flow the sections/modules tabs use, so this
// tab owns its own form state and its own "Save" button.
export function FinalTestTab({ courseId, initial, certificateRule }: FinalTestTabProps) {
  const form = useForm<FormData>({ defaultValues: configToForm(initial) });
  const questions = useFieldArray({ control: form.control, name: "questions" });

  const onSubmit = async (data: FormData) => {
    const res = await upsertFinalTestAction(courseId, {
      time_limit_minutes: data.time_limit_minutes,
      passing_score_percent: data.passing_score_percent,
      max_attempts: data.max_attempts,
      questions: data.questions.map((q) => ({
        id: q.id,
        type: q.type,
        points: q.points,
        mcq: q.type === "mcq" ? { prompt: q.prompt, multiple: q.multiple, options: q.options.map((o, i) => ({ id: `${q.id}-o${i}`, text: o.text, is_correct: o.is_correct })), explanation: q.explanation || undefined } : undefined,
        coding: q.type === "coding" ? { prompt: q.prompt, languages: q.languages, starter_code: {}, time_limit_ms: 2000, memory_limit_kb: 262144, test_cases: q.test_cases.map((c, i) => ({ id: `${q.id}-t${i}`, stdin: c.stdin, expected: c.expected, hidden: c.hidden, weight: c.weight })) } : undefined,
      })),
    });
    if (!res.ok) {
      toast.error(res.error ?? "Failed to save final test.");
      return;
    }
    toast.success("Final test saved.");
  };

  return (
    <div className="form-stack max-w-3xl">
      <CertificateRuleForm courseId={courseId} initial={certificateRule} />

      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
      <div className="grid gap-4 sm:grid-cols-3">
        <div className="flex flex-col gap-1.5">
          <Label>Time limit (minutes)</Label>
          <Input type="number" {...form.register("time_limit_minutes", { valueAsNumber: true })} />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Passing score (%)</Label>
          <Input type="number" {...form.register("passing_score_percent", { valueAsNumber: true })} />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label>Max attempts</Label>
          <Input type="number" {...form.register("max_attempts", { valueAsNumber: true })} />
        </div>
      </div>

      <div className="flex flex-col gap-4">
        {questions.fields.map((field, qi) => (
          <div className="card-base flex flex-col gap-3 p-4" key={field.id}>
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <Controller
                  control={form.control}
                  name={`questions.${qi}.type`}
                  render={({ field }) => (
                    <Select value={field.value} onValueChange={field.onChange}>
                      <SelectTrigger className="w-40"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {QUESTION_TYPE_OPTIONS.map((o) => (
                          <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
                <Input className="w-24" placeholder="points" type="number" {...form.register(`questions.${qi}.points`, { valueAsNumber: true })} />
              </div>
              <Button aria-label="Remove question" size="icon" type="button" variant="ghost" onClick={() => questions.remove(qi)}>
                <Trash2 />
              </Button>
            </div>

            <Textarea placeholder="Question prompt…" {...form.register(`questions.${qi}.prompt`)} />

            {form.watch(`questions.${qi}.type`) === "mcq" ? (
              <MCQEditor form={form} qi={qi} />
            ) : (
              <CodingEditor form={form} qi={qi} />
            )}
          </div>
        ))}
      </div>

      <div className="flex items-center justify-between">
        <Button size="sm" type="button" variant="outline" onClick={() => questions.append(makeQuestion())}>
          <Plus /> Add question
        </Button>
        <Button disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Saving…" : "Save final test"}
        </Button>
      </div>
      </form>
    </div>
  );
}

type FormType = ReturnType<typeof useForm<FormData>>;

function MCQEditor({ form, qi }: { form: FormType; qi: number }) {
  const options = useFieldArray({ control: form.control, name: `questions.${qi}.options` });
  return (
    <div className="flex flex-col gap-2">
      <Label className="flex items-center gap-2 font-normal">
        <Controller
          control={form.control}
          name={`questions.${qi}.multiple`}
          render={({ field }) => <Checkbox checked={field.value} onCheckedChange={field.onChange} />}
        />
        Allow multiple correct answers
      </Label>
      {options.fields.map((f, oi) => (
        <div className="flex items-center gap-2" key={f.id}>
          <Controller
            control={form.control}
            name={`questions.${qi}.options.${oi}.is_correct`}
            render={({ field }) => <Checkbox aria-label="Mark correct" checked={field.value} onCheckedChange={field.onChange} />}
          />
          <Input className="flex-1" placeholder={`Option ${oi + 1}`} {...form.register(`questions.${qi}.options.${oi}.text`)} />
          <Button aria-label="Remove option" size="icon" type="button" variant="ghost" onClick={() => options.remove(oi)}>
            <Trash2 />
          </Button>
        </div>
      ))}
      <Button size="sm" type="button" variant="outline" onClick={() => options.append({ text: "", is_correct: false })}>
        <Plus /> Add option
      </Button>
    </div>
  );
}

function CodingEditor({ form, qi }: { form: FormType; qi: number }) {
  const cases = useFieldArray({ control: form.control, name: `questions.${qi}.test_cases` });
  const languages = form.watch(`questions.${qi}.languages`);
  const toggleLang = (value: string, on: boolean) => {
    const next = on ? [...languages, value] : languages.filter((l) => l !== value);
    form.setValue(`questions.${qi}.languages`, next);
  };
  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap gap-3">
        {CODE_LANGUAGE_OPTIONS.map((o) => (
          <Label className="flex items-center gap-2 font-normal" key={o.value}>
            <Checkbox checked={languages.includes(o.value)} onCheckedChange={(c) => toggleLang(o.value, Boolean(c))} />
            {o.label}
          </Label>
        ))}
      </div>
      {cases.fields.map((f, ci) => (
        <div className="rounded-md border border-border p-3" key={f.id}>
          <div className="grid gap-2 sm:grid-cols-2">
            <Textarea className="min-h-16 font-mono text-xs" placeholder="stdin" {...form.register(`questions.${qi}.test_cases.${ci}.stdin`)} />
            <Textarea className="min-h-16 font-mono text-xs" placeholder="expected output" {...form.register(`questions.${qi}.test_cases.${ci}.expected`)} />
          </div>
          <div className="mt-2 flex items-center justify-between gap-2">
            <Label className="flex items-center gap-2 font-normal">
              <Controller
                control={form.control}
                name={`questions.${qi}.test_cases.${ci}.hidden`}
                render={({ field }) => <Checkbox aria-label="Hidden test case" checked={field.value} onCheckedChange={field.onChange} />}
              />
              Hidden
            </Label>
            <Input className="w-24" placeholder="weight" step="0.5" type="number" {...form.register(`questions.${qi}.test_cases.${ci}.weight`, { valueAsNumber: true })} />
            <Button aria-label="Remove case" size="icon" type="button" variant="ghost" onClick={() => cases.remove(ci)}>
              <Trash2 />
            </Button>
          </div>
        </div>
      ))}
      <Button size="sm" type="button" variant="outline" onClick={() => cases.append({ stdin: "", expected: "", hidden: false, weight: 1 })}>
        <Plus /> Add test case
      </Button>
    </div>
  );
}
