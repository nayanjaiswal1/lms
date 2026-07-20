import { notFound } from "next/navigation";
import { ClipboardList } from "lucide-react";
import { getOfflineTest } from "@/lib/server/batches";
import { EditableScoreCell } from "@/app/(app)/batches/[id]/tests/[testId]/editable-score-cell";

interface Props {
  params: Promise<{ id: string; testId: string }>;
}

export default async function OfflineTestDetailPage({ params }: Props) {
  const { id, testId } = await params;
  const test = await getOfflineTest(id, testId).catch(() => null);
  if (!test) notFound();

  const avg = test.scores.length > 0
    ? test.scores.reduce((sum, s) => sum + s.score, 0) / test.scores.length
    : 0;

  return (
    <section className="flex flex-col gap-6">
      <div className="flex items-center gap-2">
        <ClipboardList aria-hidden className="h-5 w-5 text-muted-foreground" />
        <div>
          <h2 className="section-title">{test.test_name}</h2>
          <p className="text-sm text-muted-foreground">
            {new Date(test.test_date).toLocaleDateString()} · Max {test.max_score} · Class average {avg.toFixed(1)}
          </p>
        </div>
      </div>

      <div className="table-responsive">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs text-muted-foreground">
              <th className="pb-2 pr-4 font-medium">Student</th>
              <th className="pb-2 font-medium">Score</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {test.scores.map((s) => (
              <tr key={s.user_id}>
                <td className="py-2.5 pr-4">
                  <div className="flex flex-col">
                    <span className="font-medium">{s.user_name}</span>
                    <span className="text-xs text-muted-foreground">{s.email}</span>
                  </div>
                </td>
                <td className="py-2.5">
                  <EditableScoreCell
                    batchId={id}
                    initialScore={s.score}
                    testId={testId}
                    userId={s.user_id}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
