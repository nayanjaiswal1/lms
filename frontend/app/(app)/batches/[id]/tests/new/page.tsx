import { getBatchProgress } from "@/lib/server/batches";
import { getCurrentOrgType } from "@/lib/orgs/server";
import { resolveTerminology } from "@/lib/terminology";
import { EnterScoresForm } from "@/app/(app)/batches/[id]/tests/new/enter-scores-form";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function EnterScoresPage({ params }: Props) {
  const { id } = await params;
  const [roster, orgType] = await Promise.all([
    getBatchProgress(id).catch(() => []),
    getCurrentOrgType(),
  ]);
  const t = resolveTerminology(orgType);

  return (
    <section className="flex flex-col gap-6">
      <h2 className="section-title">Enter {t.class_} Test Scores</h2>
      <EnterScoresForm batchId={id} roster={roster} t={t} />
    </section>
  );
}
