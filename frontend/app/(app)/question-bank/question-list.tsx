"use client";

import { parseAsStringLiteral, useQueryState } from "nuqs";

import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { QuestionSearchInput } from "@/app/(app)/question-bank/question-search-input";
import type { Category, Question, QuestionUsage } from "@/lib/assessments/types";

interface Props {
  questions: Question[];
  categories: Category[];
  usage: QuestionUsage[];
}

const TYPE_FILTERS = ["all", "mcq", "coding", "subjective"] as const;
const TYPE_FILTER_LABEL: Record<(typeof TYPE_FILTERS)[number], string> = {
  all:        "All types",
  mcq:        "MCQ",
  coding:     "Coding",
  subjective: "Subjective",
};

const GROUP_MODES = ["category", "course", "test", "none"] as const;
const GROUP_MODE_LABEL: Record<(typeof GROUP_MODES)[number], string> = {
  category: "Group by category",
  course:   "Group by course",
  test:     "Group by test",
  none:     "Flat list",
};

const UNCATEGORIZED = "__uncategorized";
const NOT_IN_A_TEST = "__no_test";
const NOT_IN_A_COURSE = "__no_course";

export function QuestionList({ questions, categories, usage }: Props) {
  const [type, setType] = useQueryState("type", parseAsStringLiteral(TYPE_FILTERS).withDefault("all"));
  const [group, setGroup] = useQueryState("group", parseAsStringLiteral(GROUP_MODES).withDefault("category"));

  const filtered = type === "all" ? questions : questions.filter((q) => q.type === type);

  const controls = (
    <div className="flex items-center gap-2 flex-wrap">
      <QuestionSearchInput />
      <Select value={type} onValueChange={(v) => void setType(v as (typeof TYPE_FILTERS)[number])}>
        <SelectTrigger aria-label="Filter by type" className="h-8 w-36">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {TYPE_FILTERS.map((f) => (
            <SelectItem key={f} value={f}>{TYPE_FILTER_LABEL[f]}</SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Select value={group} onValueChange={(v) => void setGroup(v as (typeof GROUP_MODES)[number])}>
        <SelectTrigger aria-label="Group by" className="h-8 w-44">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {GROUP_MODES.map((g) => (
            <SelectItem key={g} value={g}>{GROUP_MODE_LABEL[g]}</SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );

  if (filtered.length === 0) {
    return (
      <div className="flex flex-col gap-4">
        <div className="flex flex-col gap-3">
          <p className="text-sm text-muted-foreground">0 questions</p>
          {controls}
        </div>
        <p className="py-6 text-center text-sm text-muted-foreground">No questions match this filter.</p>
      </div>
    );
  }

  if (group === "none") {
    return (
      <div className="flex flex-col gap-4">
        <div className="flex flex-col gap-3">
          <p className="text-sm text-muted-foreground">
            {filtered.length} question{filtered.length === 1 ? "" : "s"}
          </p>
          {controls}
        </div>
        <QuestionTable questions={filtered} />
      </div>
    );
  }

  const groups =
    group === "category" ? groupByCategory(filtered, categories)
    : group === "course" ? groupByCourse(filtered, usage)
    : groupByTest(filtered, usage);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-3">
        <div>
          <p className="text-sm text-muted-foreground">
            {filtered.length} question{filtered.length === 1 ? "" : "s"} in {groups.length} group{groups.length === 1 ? "" : "s"}
          </p>
          {(group === "test" || group === "course") && (
            <p className="text-xs text-muted-foreground">
              A question used in more than one {group === "course" ? "course" : "test"} appears in each of them.
            </p>
          )}
        </div>
        {controls}
      </div>
      <Accordion defaultValue={groups.map((g) => g.key)} type="multiple">
        {groups.map(({ key, label, items }) => (
          <AccordionItem key={key} value={key}>
            <AccordionTrigger>
              <span className="flex items-center gap-2 normal-case tracking-normal text-foreground">
                {label}
                <Badge variant="secondary">{items.length}</Badge>
              </span>
            </AccordionTrigger>
            <AccordionContent>
              <QuestionTable questions={items} />
            </AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </div>
  );
}

interface Group {
  key: string;
  label: string;
  items: Question[];
}

function groupByCategory(questions: Question[], categories: Category[]): Group[] {
  const categoryName = new Map(categories.map((c) => [c.id, c.name]));
  const byKey = new Map<string, Question[]>();
  for (const q of questions) {
    const key = q.category_id ?? UNCATEGORIZED;
    byKey.set(key, [...(byKey.get(key) ?? []), q]);
  }
  return [...byKey.entries()]
    .map(([key, items]) => ({ key, items, label: key === UNCATEGORIZED ? "Uncategorized" : categoryName.get(key) ?? "Unknown category" }))
    .sort((a, b) => {
      if (a.key === UNCATEGORIZED) return 1;
      if (b.key === UNCATEGORIZED) return -1;
      return a.label.localeCompare(b.label);
    });
}

function groupByCourse(questions: Question[], usage: QuestionUsage[]): Group[] {
  // A question can reach the same course through several tests — dedupe to
  // one (course_id -> course_title) map per question first.
  const coursesByQuestion = new Map<string, Map<string, string>>();
  for (const u of usage) {
    if (!u.course_id || !u.course_title) continue;
    const courses = coursesByQuestion.get(u.question_id) ?? new Map<string, string>();
    courses.set(u.course_id, u.course_title);
    coursesByQuestion.set(u.question_id, courses);
  }

  const byKey = new Map<string, { label: string; items: Question[] }>();
  for (const q of questions) {
    const courses = coursesByQuestion.get(q.id);
    if (!courses || courses.size === 0) {
      const entry = byKey.get(NOT_IN_A_COURSE) ?? { label: "Not linked to a course", items: [] };
      entry.items.push(q);
      byKey.set(NOT_IN_A_COURSE, entry);
      continue;
    }
    for (const [courseId, courseTitle] of courses) {
      const entry = byKey.get(courseId) ?? { label: courseTitle, items: [] };
      entry.items.push(q);
      byKey.set(courseId, entry);
    }
  }

  return [...byKey.entries()]
    .map(([key, entry]) => ({ key, ...entry }))
    .sort((a, b) => {
      if (a.key === NOT_IN_A_COURSE) return 1;
      if (b.key === NOT_IN_A_COURSE) return -1;
      return a.label.localeCompare(b.label);
    });
}

function groupByTest(questions: Question[], usage: QuestionUsage[]): Group[] {
  const usageByQuestion = new Map<string, QuestionUsage[]>();
  for (const u of usage) {
    usageByQuestion.set(u.question_id, [...(usageByQuestion.get(u.question_id) ?? []), u]);
  }

  const byKey = new Map<string, { label: string; items: Question[] }>();
  for (const q of questions) {
    const pins = usageByQuestion.get(q.id) ?? [];
    if (pins.length === 0) {
      const entry = byKey.get(NOT_IN_A_TEST) ?? { label: "Not used in any test", items: [] };
      entry.items.push(q);
      byKey.set(NOT_IN_A_TEST, entry);
      continue;
    }
    for (const pin of pins) {
      const label = pin.course_title ? `${pin.course_title} • ${pin.assessment_title}` : pin.assessment_title;
      const entry = byKey.get(pin.assessment_id) ?? { label, items: [] };
      entry.items.push(q);
      byKey.set(pin.assessment_id, entry);
    }
  }

  return [...byKey.entries()]
    .map(([key, entry]) => ({ key, ...entry }))
    .sort((a, b) => {
      if (a.key === NOT_IN_A_TEST) return 1;
      if (b.key === NOT_IN_A_TEST) return -1;
      return a.label.localeCompare(b.label);
    });
}

function QuestionTable({ questions }: { questions: Question[] }) {
  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-muted-foreground">
            <th className="py-3 pr-4 font-medium">Title</th>
            <th className="py-3 pr-4 font-medium">Type</th>
            <th className="py-3 pr-4 font-medium">Difficulty</th>
            <th className="py-3 pr-4 font-medium">Points</th>
            <th className="py-3 pr-4 font-medium">Tags</th>
          </tr>
        </thead>
        <tbody>
          {questions.map((q) => (
            <tr className="border-b border-border/60" key={q.id}>
              <td className="py-3 pr-4 font-medium">{q.title}</td>
              <td className="py-3 pr-4">
                <Badge variant="secondary">{q.type}</Badge>
              </td>
              <td className="py-3 pr-4 capitalize text-muted-foreground">{q.difficulty}</td>
              <td className="py-3 pr-4 tabular-nums">{q.default_points}</td>
              <td className="py-3 pr-4 text-muted-foreground">{q.tags.join(", ") || "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
