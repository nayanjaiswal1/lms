import { notFound } from "next/navigation";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { TicketThread } from "@/components/tickets/ticket-thread";
import { TicketComposer } from "@/components/tickets/ticket-composer";
import { getConversationMessages } from "@/lib/server/mentoring";
import { sendConversationMessageAction } from "@/lib/mentoring/actions";
import { getCurrentUser } from "@/lib/server/auth";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Conversation" };

interface Props {
  params: Promise<{ conversationId: string }>;
}

export default async function MentorConversationChatPage({ params }: Props) {
  const { conversationId } = await params;

  const [messages, currentUser] = await Promise.all([
    getConversationMessages(conversationId).catch(() => null),
    getCurrentUser(),
  ]);

  if (messages === null) notFound();

  return (
    <main className="page-container-sm">
      <Breadcrumb
        items={[
          { label: "Conversations", href: ROUTES.MENTORING_CONVERSATIONS },
          { label: "Chat" },
        ]}
      />

      <div className="mb-6">
        <h1 className="section-title">Conversation</h1>
      </div>

      <div className="mb-6">
        <TicketThread currentUserId={currentUser?.id} messages={messages} />
      </div>

      <TicketComposer action={sendConversationMessageAction} placeholder="Write a message…" ticketId={conversationId} />
    </main>
  );
}
