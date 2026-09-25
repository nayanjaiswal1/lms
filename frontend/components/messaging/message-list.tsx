import { MessageSquare } from "lucide-react";
import { MessageItem } from "@/components/messaging/message-item";
import { MessageCompose } from "@/components/messaging/message-compose";
import type { BatchMessage } from "@/lib/server/messaging";

interface MessageListProps {
  messages: BatchMessage[];
  batchId: string;
  isStaff?: boolean;
  courseId?: string;
}

export function MessageList({ messages, batchId, isStaff, courseId }: MessageListProps) {
  return (
    <div className="flex flex-col gap-4">
      <MessageCompose batchId={batchId} />

      {messages.length === 0 ? (
        <div className="empty-state py-12">
          <MessageSquare aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 text-sm text-muted-foreground">No messages yet. Be the first to ask a question.</p>
        </div>
      ) : (
        <ol aria-label="Batch messages" className="flex flex-col gap-3">
          {messages.map((msg) => (
            <li key={msg.id}>
              <MessageItem
                batchId={batchId}
                courseId={courseId}
                isStaff={isStaff}
                message={msg}
              />
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
