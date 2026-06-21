"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { postMessageAction } from "@/lib/messaging/actions";
import type { BatchMessage } from "@/lib/server/messaging";

interface MessageComposeProps {
  batchId: string;
  parentMessage?: BatchMessage;
  onCancel?: () => void;
}

export function MessageCompose({ batchId, parentMessage, onCancel }: MessageComposeProps) {
  const [state, formAction, pending] = useActionState(
    async (_prev: { error?: string } | null, fd: FormData) => {
      const body = (fd.get("body") as string).trim();
      if (!body) return { error: "Message cannot be empty." };
      const result = await postMessageAction(batchId, {
        body,
        type: "question",
        parent_id: parentMessage?.id,
      });
      if (!result.ok) return { error: result.error };
      return null;
    },
    null,
  );

  const placeholder = parentMessage
    ? `Reply to ${parentMessage.sender_name}…`
    : "Ask a question or share a resource…";

  return (
    <form action={formAction} className="flex flex-col gap-2">
      {parentMessage && (
        <div className="rounded-md border-l-2 border-border bg-muted px-3 py-2 text-sm text-muted-foreground">
          <span className="font-medium">{parentMessage.sender_name}:</span>{" "}
          {parentMessage.body.slice(0, 80)}
          {parentMessage.body.length > 80 && "…"}
        </div>
      )}
      <Textarea
        name="body"
        placeholder={placeholder}
        rows={3}
        disabled={pending}
        className="resize-none text-sm"
        aria-label={placeholder}
      />
      {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
      <div className="flex justify-end gap-2">
        {onCancel && (
          <Button type="button" variant="ghost" size="sm" onClick={onCancel} disabled={pending}>
            Cancel
          </Button>
        )}
        <Button type="submit" size="sm" disabled={pending}>
          {pending ? "Posting…" : parentMessage ? "Reply" : "Post"}
        </Button>
      </div>
    </form>
  );
}
