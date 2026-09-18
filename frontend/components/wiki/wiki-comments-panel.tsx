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
  // One shared busy flag rather than per-comment state — simplest way to
  // block a double-submit (new comment, reply, edit, or delete firing twice
  // before the first request returns) without a state entry per comment.
  const [pending, setPending] = useState(false);

  async function submitNew(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const content = (new FormData(e.currentTarget).get("content") as string)?.trim();
    if (!content || pending) return;
    setPending(true);
    const result = await createCommentAction(pageId, { content });
    setPending(false);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Couldn't post your comment.");
      return;
    }
    const created = result.data;
    setThreads((prev) => [...prev, { ...created, replies: [] }]);
    e.currentTarget.reset();
  }

  async function submitReply(parentId: string, content: string) {
    if (pending) return;
    setPending(true);
    const result = await createCommentAction(pageId, { content, parent_id: parentId });
    setPending(false);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Couldn't post your reply.");
      return;
    }
    const created = result.data;
    setThreads((prev) => prev.map((t) => (t.id === parentId ? { ...t, replies: [...t.replies, created] } : t)));
    setActiveAction(null);
  }

  async function submitEdit(commentId: string, content: string) {
    if (pending) return;
    setPending(true);
    const result = await updateCommentAction(commentId, content);
    setPending(false);
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
    if (pending) return;
    setPending(true);
    const result = await deleteCommentAction(commentId);
    setPending(false);
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
        <Textarea disabled={pending} name="content" placeholder="Add a comment…" rows={3} />
        <Button className="w-fit" disabled={pending} type="submit">{pending ? "Posting…" : "Comment"}</Button>
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
              pending={pending}
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
                pending={pending}
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
