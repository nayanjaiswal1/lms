"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { updateOfflineTestScoreAction } from "@/app/(app)/batches/actions";

interface EditableScoreCellProps {
  batchId: string;
  testId: string;
  userId: string;
  initialScore: number;
}

export function EditableScoreCell({ batchId, testId, userId, initialScore }: EditableScoreCellProps) {
  const [score, setScore] = useState(initialScore);
  const [isPending, startTransition] = useTransition();

  const onSave = () => {
    startTransition(async () => {
      const res = await updateOfflineTestScoreAction(batchId, testId, userId, score);
      if (res.error) {
        toast.error(res.error);
        return;
      }
      toast.success("Score updated.");
    });
  };

  return (
    <div className="flex items-center gap-2">
      <Input
        className="w-20"
        disabled={isPending}
        min={0}
        step="0.5"
        type="number"
        value={score}
        onChange={(e) => setScore(Number(e.target.value))}
      />
      <Button
        disabled={isPending || score === initialScore}
        size="sm"
        variant="outline"
        onClick={onSave}
      >
        {isPending ? "Saving…" : "Save"}
      </Button>
    </div>
  );
}
