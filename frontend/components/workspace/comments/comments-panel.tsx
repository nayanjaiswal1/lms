"use client";

import { useState } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { apiFetch } from "@/lib/client/api";
import { createItemCommentAction, createQuestionCommentAction } from "@/lib/workspace/phase3-actions";
import type { WorkspaceComment } from "@/lib/workspace/phase3-server";
import type { Page } from "@/lib/workspace/types";

const MAX_LENGTH = 5000;

interface CommentsPanelProps {
  workspaceId: string;
  subjectType: "work_item" | "requirement_question";
  subjectId: string;
  initialPage: Page<WorkspaceComment>;
}

/** Flat, unthreaded comment list shared by item detail's Discussion tab and
 * the requirement question thread (contract-phase3.md — both subject types
 * ride the same widened `comments` table, viewer read / member write). */
export function CommentsPanel({ workspaceId, subjectType, subjectId, initialPage }: CommentsPanelProps) {
  const { atLeast } = useProjectRole();
  const [comments, setComments] = useState(initialPage.items);
  const [nextCursor, setNextCursor] = useState(initialPage.next_cursor);
  const [loadingMore, setLoadingMore] = useState(false);
  const [text, setText] = useState("");
  const [posting, setPosting] = useState(false);

  const listPath = subjectType === "work_item"
    ? `/workspaces/${workspaceId}/items/${subjectId}/comments`
    : `/workspaces/${workspaceId}/questions/${subjectId}/comments`;

  async function loadMore() {
    if (!nextCursor) return;
    setLoadingMore(true);
    const page = await apiFetch<Page<WorkspaceComment>>(`${listPath}?cursor=${encodeURIComponent(nextCursor)}&limit=20`);
    setLoadingMore(false);
    if (!page) {
      toast.error("Could not load more comments.");
      return;
    }
    setComments((prev) => [...prev, ...page.items]);
    setNextCursor(page.next_cursor);
  }

  async function submit() {
    const content = text.trim();
    if (content.length === 0) return;
    setPosting(true);
    const result = subjectType === "work_item"
      ? await createItemCommentAction(workspaceId, subjectId, content)
      : await createQuestionCommentAction(workspaceId, subjectId, content);
    setPosting(false);
    if (result.error || !result.data) {
      toast.error(result.error ?? "Couldn't post your comment.");
      return;
    }
    const created = result.data;
    setComments((prev) => [...prev, created]);
    setText("");
  }

  return (
    <section aria-label="Comments" className="flex flex-col gap-3">
      <h3 className="text-sm font-medium text-muted-foreground">
        Comments{comments.length > 0 && ` (${comments.length})`}
      </h3>

      {comments.length === 0 ? (
        <p className="text-sm text-muted-foreground">No comments yet.</p>
      ) : (
        <ul className="flex flex-col gap-3">
          {comments.map((c) => (
            <li className="flex flex-col gap-0.5 rounded-md border border-border p-3 text-sm" key={c.id}>
              <div className="flex items-center justify-between gap-2">
                <span className="font-medium">{c.author_name}</span>
                <span className="text-xs text-muted-foreground">{new Date(c.created_at).toLocaleString()}</span>
              </div>
              <p className="whitespace-pre-wrap">{c.content}</p>
            </li>
          ))}
        </ul>
      )}

      {nextCursor && (
        <Button className="w-fit" disabled={loadingMore} size="sm" variant="outline" onClick={() => void loadMore()}>
          {loadingMore ? "Loading…" : "Load more"}
        </Button>
      )}

      {atLeast("member") && (
        <div className="flex flex-col gap-2">
          <Textarea
            disabled={posting}
            maxLength={MAX_LENGTH}
            placeholder="Add a comment…"
            rows={3}
            value={text}
            onChange={(e) => setText(e.target.value)}
          />
          <Button className="w-fit" disabled={posting || text.trim().length === 0} size="sm" onClick={() => void submit()}>
            {posting ? "Posting…" : "Comment"}
          </Button>
        </div>
      )}
    </section>
  );
}
