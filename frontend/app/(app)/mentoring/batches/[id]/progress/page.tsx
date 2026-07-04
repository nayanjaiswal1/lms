import { BatchProgressTable } from "@/components/batches/batch-progress-table";
import { getBatchProgress } from "@/lib/server/batches";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function MentorBatchProgressPage({ params }: Props) {
  const { id } = await params;
  const progress = await getBatchProgress(id).catch(() => []);

  return (
    <div>
      <h2 className="section-title mb-4">Student Progress</h2>
      <BatchProgressTable progress={progress} />
    </div>
  );
}
