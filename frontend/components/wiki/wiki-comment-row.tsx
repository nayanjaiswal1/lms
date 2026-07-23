"use client";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import type { WikiComment } from "@/lib/server/wiki";

export type CommentAction = { type: "reply" | "edit"; id: string } | null;

interface WikiCommentRowProps {
  comment: WikiComment;
  isReply: boolean;
  currentUserId: string;
  canModerate: boolean;
  activeAction: CommentAction;
  onSetActiveAction: (action: CommentAction) => void;
  onSubmitReply: (parentId: string, content: string) => void;
  onSubmitEdit: (commentId: string, content: string) => void;
  onDelete: (commentId: string) => void;
}

/** Pure presentational row — no hooks of its own. Reply/edit "open" state and
 * form submission both live in the parent panel, kept to its 2-useState
 * budget by collapsing reply+edit into one `activeAction` value. */
export function WikiCommentRow({
  comment, isReply, currentUserId, canModerate, activeAction, onSetActiveAction,
  onSubmitReply, onSubmitEdit, onDelete,
}: WikiCommentRowProps) {
  const isOwn = comment.author_id === currentUserId;
  const canEdit = isOwn && !comment.deleted;
  const canDelete = (isOwn || canModerate) && !comment.deleted;
  const isEditing = activeAction?.type === "edit" && activeAction.id === comment.id;
  const isReplying = !isReply && activeAction?.type === "reply" && activeAction.id === comment.id;

  function handleSubmit(e: React.FormEvent<HTMLFormElement>, mode: "reply" | "edit") {
    e.preventDefault();
    const content = (new FormData(e.currentTarget).get("content") as string)?.trim();
    if (!content) return;
    if (mode === "reply") onSubmitReply(comment.id, content);
    else onSubmitEdit(comment.id, content);
    e.currentTarget.reset();
  }

  return (
    <div className={isReply ? "ml-8 mt-2" : "mt-4"}>
      <div className="rounded-lg border border-border bg-card p-3 text-sm">
        {isEditing ? (
          <form className="form-stack" onSubmit={(e) => handleSubmit(e, "edit")}>
            <Textarea autoFocus defaultValue={comment.content} name="content" rows={2} />
            <div className="flex gap-2">
              <Button size="sm" type="submit">Save</Button>
              <Button size="sm" type="button" variant="outline" onClick={() => onSetActiveAction(null)}>Cancel</Button>
            </div>
          </form>
        ) : (
          <p className={comment.deleted ? "italic text-muted-foreground" : "text-foreground"}>{comment.content}</p>
        )}

        {!isEditing && (
          <div className="mt-2 flex items-center gap-3 text-xs text-muted-foreground">
            <span>{new Date(comment.created_at).toLocaleString()}</span>
            {!isReply && !comment.deleted && (
              <button className="hover:text-foreground" type="button" onClick={() => onSetActiveAction(isReplying ? null : { type: "reply", id: comment.id })}>
                Reply
              </button>
            )}
            {canEdit && (
              <button className="hover:text-foreground" type="button" onClick={() => onSetActiveAction({ type: "edit", id: comment.id })}>
                Edit
              </button>
            )}
            {canDelete && (
              <button className="hover:text-destructive" type="button" onClick={() => onDelete(comment.id)}>
                Delete
              </button>
            )}
          </div>
        )}
      </div>

      {isReplying && (
        <form className="ml-4 mt-2 form-stack" onSubmit={(e) => handleSubmit(e, "reply")}>
          <Textarea autoFocus name="content" placeholder="Write a reply…" rows={2} />
          <div className="flex gap-2">
            <Button size="sm" type="submit">Reply</Button>
            <Button size="sm" type="button" variant="outline" onClick={() => onSetActiveAction(null)}>Cancel</Button>
          </div>
        </form>
      )}
    </div>
  );
}
