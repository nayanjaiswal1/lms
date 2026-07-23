"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import type { WikiCommentThread } from "@/lib/server/wiki";
import { createCommentAction, deleteCommentAction, updateCommentAction } from "@/lib/wiki/actions";
import { WikiCommentRow, type CommentAction } from "@/components/wiki/wiki-comment-row";

interface WikiCommentsPanelProps {
  pageId: string;
  initialThreads: WikiCommentThread[];
  currentUserId: string;
  canModerate: boolean;
}

export function WikiCommentsPanel({ pageId, initialThreads, currentUserId, canModerate }: WikiCommentsPanelProps) {
  const [threads, setThreads] = useState(initialThreads);
  const [activeAction, setActiveAction] = useState<CommentAction>(null);

  async function submitNew(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const content = (new FormData(e.currentTarget).get("content") as string)?.trim();
    if (!content) return;
    const result = await createCommentAction(pageId, { content });
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Couldn't post your comment.");
      return;
    }
    const created = result.data;
    setThreads((prev) => [...prev, { ...created, replies: [] }]);
    e.currentTarget.reset();
  }

  async function submitReply(parentId: string, content: string) {
    const result = await createCommentAction(pageId, { content, parent_id: parentId });
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Couldn't post your reply.");
      return;
    }
    const created = result.data;
    setThreads((prev) => prev.map((t) => (t.id === parentId ? { ...t, replies: [...t.replies, created] } : t)));
    setActiveAction(null);
  }

  async function submitEdit(commentId: string, content: string) {
    const result = await updateCommentAction(commentId, content);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Couldn't save your edit.");
      return;
    }
    const updatedContent = result.data.content;
    setThreads((prev) => prev.map((t) => {
      if (t.id === commentId) return { ...t, content: updatedContent };
      return { ...t, replies: t.replies.map((r) => (r.id === commentId ? { ...r, content: updatedContent } : r)) };
    }));
    setActiveAction(null);
  }

  async function handleDelete(commentId: string) {
    const result = await deleteCommentAction(commentId);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't delete that comment.");
      return;
    }
    setThreads((prev) => prev.map((t) => {
      if (t.id === commentId) return { ...t, deleted: true, content: "[deleted]" };
      return { ...t, replies: t.replies.map((r) => (r.id === commentId ? { ...r, deleted: true, content: "[deleted]" } : r)) };
    }));
  }

  const commentCount = threads.reduce((n, t) => n + 1 + t.replies.length, 0);

  return (
    <section aria-label="Comments" className="mt-8 border-t border-border pt-6">
      <h2 className="section-title">Comments{commentCount > 0 && ` (${commentCount})`}</h2>

      <form className="form-stack mt-4" onSubmit={(e) => void submitNew(e)}>
        <Textarea name="content" placeholder="Add a comment…" rows={3} />
        <Button className="w-fit" type="submit">Comment</Button>
      </form>

      <div>
        {threads.map((thread) => (
          <div key={thread.id}>
            <WikiCommentRow
              activeAction={activeAction}
              canModerate={canModerate}
              comment={thread}
              currentUserId={currentUserId}
              isReply={false}
              onDelete={handleDelete}
              onSetActiveAction={setActiveAction}
              onSubmitEdit={submitEdit}
              onSubmitReply={submitReply}
            />
            {thread.replies.map((reply) => (
              <WikiCommentRow
                isReply
                activeAction={activeAction}
                canModerate={canModerate}
                comment={reply}
                currentUserId={currentUserId}
                key={reply.id}
                onDelete={handleDelete}
                onSetActiveAction={setActiveAction}
                onSubmitEdit={submitEdit}
                onSubmitReply={submitReply}
              />
            ))}
          </div>
        ))}
      </div>
    </section>
  );
}
