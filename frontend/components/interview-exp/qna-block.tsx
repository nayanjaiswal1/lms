import { VoteButtons } from "@/components/interview-exp/vote-buttons";
import { CommentNode } from "@/components/interview-exp/comment-node";
import { AddCommentForm } from "@/components/interview-exp/add-comment-form";
import type { QnaWithComments } from "@/lib/server/interview-exp";

interface QnaBlockProps {
  qna: QnaWithComments;
}

// Server component — composes client leaves (VoteButtons, CommentNode,
// AddCommentForm) but holds no state of its own.
export function QnaBlock({ qna }: QnaBlockProps) {
  return (
    <div className="card-base flex gap-3 p-4">
      <VoteButtons myVote={qna.my_vote} score={qna.score} targetId={qna.id} targetType="qna" />
      <div className="flex flex-1 flex-col gap-2">
        <p className="font-medium text-foreground">{qna.question}</p>
        {qna.answer && <p className="whitespace-pre-wrap text-sm text-muted-foreground">{qna.answer}</p>}

        {qna.comments.length > 0 && (
          <div className="mt-2 flex flex-col gap-3 border-t border-border pt-3">
            {qna.comments.map((c) => (
              <CommentNode comment={c} key={c.id} qnaId={qna.id} />
            ))}
          </div>
        )}

        <div className="mt-2">
          <AddCommentForm placeholder="Discuss this question…" qnaId={qna.id} />
        </div>
      </div>
    </div>
  );
}
