"use client";

import { useRef, useState, useTransition } from "react";
import { Loader2, Send, Sparkles } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { sendDesignChatMessageAction } from "@/lib/design-actions";
import type { DesignChatMessage } from "@/lib/design";

interface DesignChatPanelProps {
  moduleId: string;
  initialMessages: DesignChatMessage[];
}

// "Ask clarifying questions" tab — a chat thread grounded in the question's
// guidance, scoped per student per question (persists across attempts).
export function DesignChatPanel({ moduleId, initialMessages }: DesignChatPanelProps) {
  const [messages, setMessages] = useState(initialMessages);
  const [draft, setDraft] = useState("");
  const [isSending, startSending] = useTransition();
  const formRef = useRef<HTMLFormElement>(null);

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    const content = draft.trim();
    if (!content || isSending) return;
    setDraft("");
    startSending(async () => {
      const result = await sendDesignChatMessageAction(moduleId, content);
      const newMessages = result.data;
      if (result.error || !newMessages) {
        toast.error(result.error ?? "Failed to send message.");
        setDraft(content);
        return;
      }
      setMessages((prev) => [...prev, ...newMessages]);
    });
  };

  return (
    <div className="flex h-full flex-col gap-3">
      <div className="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto">
        {messages.length === 0 && (
          <p className="text-sm text-muted-foreground">
            Ask anything about this question — scope, edge cases, what the interviewer is probing for.
          </p>
        )}
        {messages.map((m) => (
          <div
            className={cn(
              "max-w-[85%] rounded-lg px-3 py-2 text-sm",
              m.role === "assistant" ? "ai-surface self-start" : "self-end bg-primary text-primary-foreground",
            )}
            key={m.id}
          >
            {m.role === "assistant" && (
              <span className="ai-badge mb-1 inline-flex items-center gap-1">
                <Sparkles aria-hidden className="h-3 w-3" />AI
              </span>
            )}
            <p className="whitespace-pre-wrap leading-relaxed">{m.content}</p>
          </div>
        ))}
        {isSending && (
          <div className="ai-surface flex max-w-[85%] items-center gap-2 self-start rounded-lg px-3 py-2 text-sm text-muted-foreground">
            <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />Thinking…
          </div>
        )}
      </div>
      <form className="flex items-end gap-2" ref={formRef} onSubmit={handleSubmit}>
        <Textarea
          className="min-h-11 resize-none"
          disabled={isSending}
          placeholder="Ask about this system design question…"
          rows={2}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              formRef.current?.requestSubmit();
            }
          }}
        />
        <Button aria-label="Send question" className="touch-target" disabled={isSending || !draft.trim()} size="icon" type="submit">
          <Send aria-hidden className="h-4 w-4" />
        </Button>
      </form>
    </div>
  );
}
