"use client";

import { useState } from "react";
import { Pin, CheckCircle2, ThumbsUp, Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { resolveMessageAction, promoteFAQAction } from "@/lib/messaging/actions";
import { MessageCompose } from "@/components/messaging/message-compose";
import type { BatchMessage } from "@/lib/server/messaging";

interface MessageItemProps {
  message: BatchMessage;
  batchId: string;
  isStaff?: boolean;
  courseId?: string;
}

export function MessageItem({ message, batchId, isStaff, courseId }: MessageItemProps) {
  const [showReply, setShowReply] = useState(false);

  const upvote = message.reactions.find((r) => r.reaction === "upvote");
  const helpful = message.reactions.find((r) => r.reaction === "helpful");

  async function handleResolve() {
    await resolveMessageAction(message.id, batchId);
  }

  async function handlePromoteFAQ() {
    if (!courseId) return;
    await promoteFAQAction(message.id, {
      course_id: courseId,
      question: message.body,
      answer: "",
    });
  }

  return (
    <article
      className={cn(
        "card-base flex flex-col gap-3 p-4",
        message.is_pinned && "border-primary/40",
        message.is_resolved && "opacity-80",
      )}
    >
      <header className="flex items-center gap-2">
        <div className="flex h-8 w-8 items-center justify-center rounded-full bg-muted text-xs font-semibold">
          {message.sender_name.charAt(0).toUpperCase()}
        </div>
        <div className="flex flex-1 flex-col">
          <span className="text-sm font-medium">{message.sender_name}</span>
          <span className="text-xs text-muted-foreground">
            {new Date(message.created_at).toLocaleString()}
            {message.edited_at && " (edited)"}
          </span>
        </div>
        <div className="flex items-center gap-1">
          {message.is_pinned && <Pin aria-label="Pinned" className="h-3.5 w-3.5 text-primary" />}
          {message.is_resolved && <CheckCircle2 aria-label="Resolved" className="h-3.5 w-3.5 text-primary" />}
          {message.type !== "question" && (
            <span className="rounded-full bg-muted px-2 py-0.5 text-xs font-medium capitalize text-muted-foreground">
              {message.type}
            </span>
          )}
        </div>
      </header>

      {message.body === "[deleted]" ? (
        <p className="text-sm italic text-muted-foreground">[message deleted]</p>
      ) : (
        <p className="whitespace-pre-wrap text-sm leading-relaxed">{message.body}</p>
      )}

      <footer className="flex flex-wrap items-center gap-2">
        {upvote && (
          <span className="flex items-center gap-1 text-xs text-muted-foreground">
            <ThumbsUp aria-hidden className="h-3.5 w-3.5" />
            {upvote.count}
          </span>
        )}
        {helpful && (
          <span className="flex items-center gap-1 text-xs text-muted-foreground">
            <Star aria-hidden className="h-3.5 w-3.5" />
            {helpful.count}
          </span>
        )}
        {message.reply_count > 0 && (
          <span className="text-xs text-muted-foreground">{message.reply_count} replies</span>
        )}
        <div className="ml-auto flex items-center gap-1">
          <Button variant="ghost" size="sm" className="h-7 text-xs" onClick={() => setShowReply((v) => !v)}>
            Reply
          </Button>
          {isStaff && !message.is_resolved && (
            <Button variant="ghost" size="sm" className="h-7 text-xs" onClick={handleResolve}>
              Resolve
            </Button>
          )}
          {isStaff && courseId && (
            <Button variant="ghost" size="sm" className="h-7 text-xs" onClick={handlePromoteFAQ}>
              → FAQ
            </Button>
          )}
        </div>
      </footer>

      {showReply && (
        <div className="border-t border-border pt-3">
          <MessageCompose batchId={batchId} parentMessage={message} onCancel={() => setShowReply(false)} />
        </div>
      )}
    </article>
  );
}
