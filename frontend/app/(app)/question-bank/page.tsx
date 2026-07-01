import type { Metadata } from "next";
import { FileQuestion } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { getQuestions } from "@/lib/server/assessments";
import { QuestionBankPanel } from "@/app/(app)/question-bank/question-bank-panel";

export const metadata: Metadata = {
  title: "Question Bank",
  description: "Author and manage MCQ and coding questions.",
};

export default async function QuestionBankPage() {
  const { questions, total } = await getQuestions("?limit=100");

  return (
    <main className="page-container py-10">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Question Bank</h1>
          <p className="text-muted-foreground">{total} reusable questions across your organisation.</p>
        </div>
        <QuestionBankPanel />
      </header>

      {questions.length === 0 ? (
        <div className="empty-state mt-10">
          <FileQuestion aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No questions yet</p>
          <p className="text-sm text-muted-foreground">Create your first MCQ or coding question to build assessments.</p>
        </div>
      ) : (
        <div className="table-responsive mt-8">
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
      )}
    </main>
  );
}
