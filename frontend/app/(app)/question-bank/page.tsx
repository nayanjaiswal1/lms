import type { Metadata } from "next";
import { FileQuestion } from "lucide-react";

import { getCategories, getQuestions, getQuestionUsage } from "@/lib/assessments/server";
import { QuestionBankPanel } from "@/app/(app)/question-bank/question-bank-panel";
import { QuestionList } from "@/app/(app)/question-bank/question-list";

export const metadata: Metadata = {
  title: "Question Bank",
  description: "Author and manage MCQ and coding questions.",
};

interface QuestionBankPageProps {
  searchParams: Promise<{ search?: string }>;
}

export default async function QuestionBankPage({ searchParams }: QuestionBankPageProps) {
  const { search } = await searchParams;
  const query = search?.trim() ?? "";
  const qs = query ? `&search=${encodeURIComponent(query)}` : "";

  const [{ questions, total }, categories, usage] = await Promise.all([
    getQuestions(`?limit=200${qs}`),
    getCategories(),
    getQuestionUsage(),
  ]);

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Question Bank</h1>
          <p className="text-muted-foreground">{total} reusable questions across your organisation.</p>
        </div>
        <QuestionBankPanel categories={categories} />
      </header>

      {questions.length === 0 && !query ? (
        <div className="empty-state mt-10">
          <FileQuestion aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No questions yet</p>
          <p className="text-sm text-muted-foreground">Create your first MCQ or coding question to build assessments.</p>
        </div>
      ) : (
        <div className="mt-8">
          <QuestionList categories={categories} questions={questions} usage={usage} />
        </div>
      )}
    </main>
  );
}
