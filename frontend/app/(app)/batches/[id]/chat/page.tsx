import { notFound } from "next/navigation";
import { MessageSquare } from "lucide-react";
import { getBatchMessages } from "@/lib/server/messaging";
import { MessageList } from "@/components/messaging/message-list";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function BatchChatPage({ params }: Props) {
  const { id } = await params;

  const messages = await getBatchMessages(id, { limit: 50 }).catch(() => []);

  return (
    <section className="flex flex-col gap-6">
      <div className="flex items-center gap-2">
        <MessageSquare aria-hidden className="h-5 w-5 text-muted-foreground" />
        <h2 className="section-title">Chat</h2>
      </div>
      <MessageList messages={messages} batchId={id} isStaff />
    </section>
  );
}
