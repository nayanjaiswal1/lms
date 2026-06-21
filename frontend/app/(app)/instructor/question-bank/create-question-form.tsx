"use client";

import * as React from "react";
import { useForm, useFieldArray, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  QUESTION_TYPE,
  QUESTION_TYPE_OPTIONS,
  ASSESSMENT_DIFFICULTY_OPTIONS,
  CODE_LANGUAGE_OPTIONS,
} from "@/lib/constants";
import { createQuestionAction } from "@/app/instructor/question-bank/actions";

const numeric = z.string().refine((v) => v !== "" && !Number.isNaN(Number(v)), "Enter a number.");

const Schema = z.object({
  type: z.enum(["mcq", "coding"]),
  title: z.string().min(3, "Title is too short."),
  difficulty: z.string(),
  default_points: numeric,
  tags: z.string(),
  prompt: z.string().min(3, "Prompt is required."),
  multiple: z.boolean(),
  explanation: z.string(),
  options: z.array(z.object({ text: z.string(), is_correct: z.boolean() })),
  languages: z.array(z.string()),
  test_cases: z.array(z.object({ stdin: z.string(), expected: z.string(), hidden: z.boolean(), weight: numeric })),
});
type FormData = z.infer<typeof Schema>;

interface CreateQuestionFormProps {
  onCreated: () => void;
}

export function CreateQuestionForm({ onCreated }: CreateQuestionFormProps) {
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      type: "mcq",
      title: "",
      difficulty: "intermediate",
      default_points: "1",
      tags: "",
      prompt: "",
      multiple: false,
      explanation: "",
      options: [
        { text: "", is_correct: true },
        { text: "", is_correct: false },
      ],
      languages: ["python"],
      test_cases: [{ stdin: "", expected: "", hidden: false, weight: "1" }],
    },
  });
  const options = useFieldArray({ control: form.control, name: "options" });
  const cases = useFieldArray({ control: form.control, name: "test_cases" });
  const type = form.watch("type");

  const onSubmit = async (data: FormData) => {
    const res = await createQuestionAction({
      type: data.type,
      title: data.title,
      difficulty: data.difficulty,
      default_points: Number(data.default_points),
      tags: data.tags.split(",").map((t) => t.trim()).filter(Boolean),
      prompt: data.prompt,
      multiple: data.multiple,
      options: data.options,
      explanation: data.explanation,
      languages: data.languages,
      test_cases: data.test_cases.map((c) => ({ ...c, weight: Number(c.weight) })),
    });
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Question created.");
    form.reset();
    onCreated();
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="type"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Question type</FormLabel>
              <Select value={field.value} onValueChange={field.onChange}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  {QUESTION_TYPE_OPTIONS.map((o) => (
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

        <FormInputField control={form.control} label="Title" name="title" placeholder="e.g. Two Sum" />

        <div className="grid gap-4 sm:grid-cols-3">
          <FormField
            control={form.control}
            name="difficulty"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Difficulty</FormLabel>
                <Select value={field.value} onValueChange={field.onChange}>
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {ASSESSMENT_DIFFICULTY_OPTIONS.map((o) => (
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
          <FormInputField control={form.control} label="Points" name="default_points" type="number" />
          <FormInputField control={form.control} label="Tags (comma sep)" name="tags" placeholder="arrays, hashing" />
        </div>

        <FormField
          control={form.control}
          name="prompt"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Prompt</FormLabel>
              <FormControl>
                <Textarea placeholder="Describe the question…" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        {type === QUESTION_TYPE.MCQ ? (
          <MCQEditor form={form} options={options} />
        ) : (
          <CodingEditor cases={cases} form={form} />
        )}

        <Button disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Saving…" : "Create question"}
        </Button>
      </form>
    </Form>
  );
}

type FormType = ReturnType<typeof useForm<FormData>>;

function MCQEditor({ form, options }: { form: FormType; options: ReturnType<typeof useFieldArray<FormData, "options">> }) {
  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <FormField
          control={form.control}
          name="multiple"
          render={({ field }) => (
            <FormItem className="flex flex-row items-center gap-2">
              <FormControl>
                <Checkbox checked={field.value} onCheckedChange={field.onChange} />
              </FormControl>
              <FormLabel className="font-normal">Allow multiple correct answers</FormLabel>
            </FormItem>
          )}
        />
      </div>
      <Label>Options (check the correct one)</Label>
      {options.fields.map((f, i) => (
        <div className="flex items-center gap-2" key={f.id}>
          <Controller
            control={form.control}
            name={`options.${i}.is_correct`}
            render={({ field }) => (
              <Checkbox
                aria-label="Mark correct"
                checked={field.value}
                onCheckedChange={field.onChange}
              />
            )}
          />
          <Input className="flex-1" placeholder={`Option ${i + 1}`} {...form.register(`options.${i}.text`)} />
          <Button aria-label="Remove option" size="icon" type="button" variant="ghost" onClick={() => options.remove(i)}>
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

function CodingEditor({ form, cases }: { form: FormType; cases: ReturnType<typeof useFieldArray<FormData, "test_cases">> }) {
  const langs = form.watch("languages");
  const toggleLang = (value: string, on: boolean) => {
    const next = on ? [...langs, value] : langs.filter((l) => l !== value);
    form.setValue("languages", next);
  };
  return (
    <div className="flex flex-col gap-3">
      <Label>Allowed languages</Label>
      <div className="flex flex-wrap gap-3">
        {CODE_LANGUAGE_OPTIONS.map((o) => (
          <Label className="flex items-center gap-2 font-normal" key={o.value}>
            <Checkbox checked={langs.includes(o.value)} onCheckedChange={(c) => toggleLang(o.value, Boolean(c))} />
            {o.label}
          </Label>
        ))}
      </div>

      <Label>Test cases (mark some hidden)</Label>
      {cases.fields.map((f, i) => (
        <div className="card-base flex flex-col gap-2 p-3" key={f.id}>
          <div className="grid gap-2 sm:grid-cols-2">
            <Textarea className="min-h-16 font-mono text-xs" placeholder="stdin" {...form.register(`test_cases.${i}.stdin`)} />
            <Textarea className="min-h-16 font-mono text-xs" placeholder="expected output" {...form.register(`test_cases.${i}.expected`)} />
          </div>
          <div className="flex items-center justify-between gap-2">
            <Label className="flex items-center gap-2 font-normal">
              <Controller
                control={form.control}
                name={`test_cases.${i}.hidden`}
                render={({ field }) => (
                  <Checkbox aria-label="Hidden test case" checked={field.value} onCheckedChange={field.onChange} />
                )}
              />
              Hidden
            </Label>
            <Input className="w-24" placeholder="weight" step="0.5" type="number" {...form.register(`test_cases.${i}.weight`)} />
            <Button aria-label="Remove case" size="icon" type="button" variant="ghost" onClick={() => cases.remove(i)}>
              <Trash2 />
            </Button>
          </div>
        </div>
      ))}
      <Button size="sm" type="button" variant="outline" onClick={() => cases.append({ stdin: "", expected: "", hidden: false, weight: "1" })}>
        <Plus /> Add test case
      </Button>
    </div>
  );
}
