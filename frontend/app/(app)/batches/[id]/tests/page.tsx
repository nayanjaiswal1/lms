import Link from "next/link";
import { ClipboardList, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { listOfflineTests } from "@/lib/server/batches";
import { getCurrentOrgType } from "@/lib/orgs/server";
import { resolveTerminology } from "@/lib/terminology";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function OfflineTestsPage({ params }: Props) {
  const { id } = await params;
  const [tests, orgType] = await Promise.all([
    listOfflineTests(id).catch(() => []),
    getCurrentOrgType(),
  ]);
  const t = resolveTerminology(orgType);

  return (
    <section className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <ClipboardList aria-hidden className="h-5 w-5 text-muted-foreground" />
          <h2 className="section-title">{t.class_} Test Results</h2>
        </div>
        <Button asChild size="sm">
          <Link href={`${ROUTES.batch(id)}/tests/new`}>
            <Plus aria-hidden className="mr-1.5 h-4 w-4" />
            Enter Scores
          </Link>
        </Button>
      </div>

      {tests.length === 0 ? (
        <div className="empty-state py-10">
          <ClipboardList aria-hidden className="h-8 w-8 text-muted-foreground" />
          <p className="mt-2 text-sm text-muted-foreground">No test results entered yet.</p>
        </div>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="pb-2 pr-4 font-medium">Test</th>
                <th className="pb-2 pr-4 font-medium">Date</th>
                <th className="pb-2 pr-4 font-medium">Max score</th>
                <th className="pb-2 pr-4 font-medium">{t.studentPlural} entered</th>
                <th className="pb-2 font-medium">Class average</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {tests.map((test) => (
                <tr key={test.test_id}>
                  <td className="py-2.5 pr-4">
                    <Link
                      className="font-medium text-primary hover:underline"
                      href={`${ROUTES.batch(id)}/tests/${test.test_id}`}
                    >
                      {test.test_name}
                    </Link>
                  </td>
                  <td className="py-2.5 pr-4 text-muted-foreground">
                    {new Date(test.test_date).toLocaleDateString()}
                  </td>
                  <td className="py-2.5 pr-4 tabular-nums">{test.max_score}</td>
                  <td className="py-2.5 pr-4 tabular-nums">{test.student_count}</td>
                  <td className="py-2.5 tabular-nums font-medium">{test.avg_score.toFixed(1)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
