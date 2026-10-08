import { LoadMoreButton } from "@/components/shared/load-more-button";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { ANALYTICS_MAX_LIMIT, ANALYTICS_PAGE_STEP, ANALYTICS_QUESTIONS_DEFAULT_LIMIT } from "@/lib/constants";
import type { HardestQuestions } from "@/lib/server/course-analytics";

export function HardestQuestionsTable({ data }: { data: HardestQuestions }) {
  if (data.questions.length === 0) {
    return (
      <div className="empty-state py-10">
        <p className="text-sm text-muted-foreground">Not enough quiz answers yet to rank questions.</p>
      </div>
    );
  }
  return (
    <>
      <ResponsiveTable>
        <table className="w-full text-sm">
          <thead>
            <tr className="whitespace-nowrap border-b border-border text-left text-xs text-muted-foreground">
              <th className="pb-2 font-medium">Question</th>
              <th className="pb-2 font-medium">Lesson</th>
              <th className="pb-2 font-medium">Answers</th>
              <th className="pb-2 font-medium">Correct</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {data.questions.map((q) => (
              <tr className="whitespace-nowrap" key={q.assessment_question_id}>
                <td className="max-w-xs py-3 pr-4"><p className="truncate font-medium">{q.title}</p></td>
                <td className="max-w-xs py-3 pr-4"><p className="truncate text-muted-foreground">{q.module_title}</p></td>
                <td className="py-3 pr-4">{q.answered} ({q.students} students)</td>
                <td className="py-3 font-medium text-primary">{Math.round(q.correct_rate * 100)}%</td>
              </tr>
            ))}
          </tbody>
        </table>
      </ResponsiveTable>
      <LoadMoreButton
        defaultLimit={ANALYTICS_QUESTIONS_DEFAULT_LIMIT}
        hasMore={data.questions.length < data.total}
        max={ANALYTICS_MAX_LIMIT}
        param="q_limit"
        step={ANALYTICS_PAGE_STEP}
      />
    </>
  );
}
