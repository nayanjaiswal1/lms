import { notFound } from "next/navigation";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { getBatch } from "@/lib/server/batches";
import { getBatchMessages } from "@/lib/server/messaging";
import { MessageList } from "@/components/messaging/message-list";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const batch = await getBatch(id).catch(() => null);
  return { title: batch ? `${batch.name} Chat — MindForge` : "Batch Chat — MindForge" };
}

export default async function BatchChatPage({ params }: Props) {
  const { id } = await params;

  const [batch, messages] = await Promise.all([
    getBatch(id).catch(() => null),
    getBatchMessages(id, { limit: 50 }).catch(() => []),
  ]);

  if (!batch) notFound();

  return (
    <main className="page-container py-8">
      <div className="mb-6 flex items-center gap-3">
        <Link href={ROUTES.mentoringBatch(id)} className="text-muted-foreground hover:text-foreground">
          <ArrowLeft aria-label="Back to batch" className="h-5 w-5" />
        </Link>
        <h1 className="page-title">{batch.name} — Chat</h1>
      </div>

      <MessageList messages={messages} batchId={id} isStaff />
    </main>
  );
}
