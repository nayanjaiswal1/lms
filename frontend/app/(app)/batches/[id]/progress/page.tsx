import { BarChart3 } from "lucide-react";
import { BatchProgressTable } from "@/components/batches/batch-progress-table";
import { getBatchProgress } from "@/lib/server/batches";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function BatchProgressPage({ params }: Props) {
  const { id } = await params;
  const progress = await getBatchProgress(id).catch(() => []);

  return (
    <section className="flex flex-col gap-6">
      <div className="flex items-center gap-2">
        <BarChart3 aria-hidden className="h-5 w-5 text-muted-foreground" />
        <h2 className="section-title">Student Progress</h2>
      </div>
      <BatchProgressTable progress={progress} />
    </section>
  );
}
