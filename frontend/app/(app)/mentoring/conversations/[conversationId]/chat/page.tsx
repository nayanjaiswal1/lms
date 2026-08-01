import { notFound } from "next/navigation";
import { MessageSquare } from "lucide-react";
import { cn } from "@/lib/utils";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { MentorDmComposer } from "@/components/mentoring/mentor-dm-composer";
import { getConversationMessages } from "@/lib/server/mentoring";
import { getCurrentUser } from "@/lib/server/auth";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Conversation — MindForge" };

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

      {messages.length === 0 ? (
        <div className="empty-state py-12">
          <MessageSquare aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 text-sm text-muted-foreground">No messages yet. Say hello!</p>
        </div>
      ) : (
        <ol aria-label="Chat messages" className="mb-6 flex flex-col gap-3">
          {messages.map((msg) => {
            const isMine = msg.sender_id === currentUser?.id;
            return (
              <li className={cn("flex", isMine ? "justify-end" : "justify-start")} key={msg.id}>
                <div
                  className={cn(
                    "max-w-[80%] rounded-lg px-4 py-2.5 text-sm",
                    isMine ? "bg-primary text-primary-foreground" : "bg-muted text-foreground",
                  )}
                >
                  <p className="whitespace-pre-wrap">{msg.body}</p>
                  <p
                    className={cn(
                      "mt-1 text-xs",
                      isMine ? "text-primary-foreground/70" : "text-muted-foreground",
                    )}
                  >
                    {new Date(msg.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                  </p>
                </div>
              </li>
            );
          })}
        </ol>
      )}

      <MentorDmComposer conversationId={conversationId} />
    </main>
  );
}
