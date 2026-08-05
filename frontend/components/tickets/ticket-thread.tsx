import { cn } from "@/lib/utils";

interface ThreadMessage {
  id: string;
  sender_id: string;
  body: string;
  created_at: string;
}

interface TicketThreadProps {
  messages: ThreadMessage[];
  currentUserId?: string;
}

// Shared message-bubble list — the support ticket floating panel, the mentor
// ticket chat page, and the mentor DM chat page all render the exact same
// bubble shape; this is the one implementation all three use.
export function TicketThread({ messages, currentUserId }: TicketThreadProps) {
  if (messages.length === 0) {
    return <p className="text-sm text-muted-foreground">No messages yet.</p>;
  }

  return (
    <ol aria-label="Messages" className="flex flex-col gap-3">
      {messages.map((msg) => {
        const isMine = msg.sender_id === currentUserId;
        return (
          <li className={cn("flex", isMine ? "justify-end" : "justify-start")} key={msg.id}>
            <div
              className={cn(
                "max-w-[85%] rounded-lg px-3 py-2 text-sm",
                isMine ? "bg-primary text-primary-foreground" : "bg-muted text-foreground",
              )}
            >
              <p className="whitespace-pre-wrap">{msg.body}</p>
              <p className={cn("mt-1 text-[10px]", isMine ? "text-primary-foreground/70" : "text-muted-foreground")}>
                {new Date(msg.created_at).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" })}
              </p>
            </div>
          </li>
        );
      })}
    </ol>
  );
}
