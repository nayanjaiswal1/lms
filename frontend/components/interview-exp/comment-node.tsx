"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { VoteButtons } from "@/components/interview-exp/vote-buttons";
import { AddCommentForm } from "@/components/interview-exp/add-comment-form";
import type { Comment } from "@/lib/server/interview-exp";

// Nesting is unlimited in the data model, but indentation is capped at 6
// levels so a very deep thread doesn't push content off-screen on mobile.
const INDENT_CLASS = ["ml-0", "ml-3", "ml-6", "ml-9", "ml-12", "ml-14", "ml-16"];

interface CommentNodeProps {
  comment: Comment;
  qnaId: string;
  depth?: number;
}

export function CommentNode({ comment, qnaId, depth = 0 }: CommentNodeProps) {
  const [showReply, setShowReply] = useState(false);
  const indent = INDENT_CLASS[Math.min(depth, INDENT_CLASS.length - 1)];

  return (
    <div className={cn("flex flex-col gap-2 border-l border-border pl-3", indent)}>
      <div className="flex gap-2">
        <VoteButtons myVote={comment.my_vote} score={comment.score} targetId={comment.id} targetType="comment" />
        <div className="flex flex-1 flex-col gap-1">
          <p className={cn("text-sm", comment.deleted ? "italic text-muted-foreground" : "text-foreground")}>
            {comment.content}
          </p>
          <div className="flex items-center gap-2">
            <span className="text-xs text-muted-foreground">
              {new Date(comment.created_at).toLocaleDateString()}
            </span>
            {!comment.deleted && (
              <Button
                className="touch-target h-auto p-0 text-xs text-muted-foreground"
                size="sm"
                variant="ghost"
                onClick={() => setShowReply((v) => !v)}
              >
                Reply
              </Button>
            )}
          </div>
          {showReply && (
            <AddCommentForm parentId={comment.id} qnaId={qnaId} onDone={() => setShowReply(false)} />
          )}
        </div>
      </div>

      {comment.replies.map((reply) => (
        <CommentNode comment={reply} depth={depth + 1} key={reply.id} qnaId={qnaId} />
      ))}
    </div>
  );
}
