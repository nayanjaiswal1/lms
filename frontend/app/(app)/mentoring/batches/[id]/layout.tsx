import { notFound } from "next/navigation";
import Link from "next/link";
import { MessageSquare } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { BatchTabNav } from "@/components/batches/batch-tab-nav";
import { getBatch } from "@/lib/server/batches";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
  children: React.ReactNode;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const batch = await getBatch(id).catch(() => null);
  return { title: batch ? `${batch.name} — MindForge` : "Batch — MindForge" };
}

export default async function MentorBatchLayout({ params, children }: Props) {
  const { id } = await params;
  const batch = await getBatch(id).catch(() => null);

  if (!batch) notFound();

  return (
    <main className="page-container py-8">
      <div className="page-header">
        <div className="flex items-center gap-3">
          <h1 className="page-title">{batch.name}</h1>
          <Badge variant={batch.status === "active" ? "default" : "secondary"}>
            {batch.status}
          </Badge>
        </div>
        <Button asChild variant="outline">
          <Link href={ROUTES.mentoringBatchChat(id)}>
            <MessageSquare aria-hidden className="mr-2 h-4 w-4" />
            Open chat
          </Link>
        </Button>
      </div>

      {batch.description && (
        <p className="mb-6 text-muted-foreground">{batch.description}</p>
      )}

      <BatchTabNav batchId={id} />

      <div>{children}</div>
    </main>
  );
}
