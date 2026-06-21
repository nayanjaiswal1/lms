"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus, Trash2, Rocket, Users } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import {
  addAssessmentQuestionAction,
  removeAssessmentQuestionAction,
  publishAssessmentAction,
  assignAssessmentAction,
} from "@/app/instructor/assessments/actions";
import type { Assessment, Question, Batch } from "@/lib/assessments/types";
import type { AssessmentQuestionFull } from "@/lib/server/assessments";

interface AssessmentBuilderProps {
  assessment: Assessment;
  attached: AssessmentQuestionFull[];
  bank: Question[];
  batches: Batch[];
}

export function AssessmentBuilder({ assessment, attached, bank, batches }: AssessmentBuilderProps) {
  const router = useRouter();
  const [busy, setBusy] = React.useState(false);
  const [selectedBatches, setSelectedBatches] = React.useState<string[]>([]);

  const attachedIds = new Set(attached.map((q) => q.question_id));
  const available = bank.filter((q) => !attachedIds.has(q.id));
  const isDraft = assessment.status === "draft";

  const run = async (fn: () => Promise<{ ok?: boolean; error?: string }>, success: string) => {
    setBusy(true);
    const res = await fn();
    setBusy(false);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success(success);
    router.refresh();
  };

  const toggleBatch = (id: string, on: boolean) =>
    setSelectedBatches((prev) => (on ? [...prev, id] : prev.filter((b) => b !== id)));

  return (
    <main className="page-container py-10">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <h1 className="page-title">{assessment.title}</h1>
            <Badge variant={isDraft ? "outline" : "default"}>{assessment.status}</Badge>
          </div>
          <p className="text-muted-foreground">
            {attached.length} questions · {assessment.total_points} points · {assessment.duration_minutes} min
          </p>
        </div>
        {isDraft && (
          <Button
            disabled={busy || attached.length === 0}
            onClick={() => run(() => publishAssessmentAction(assessment.id), "Assessment published.")}
          >
            <Rocket /> Publish
          </Button>
        )}
      </header>

      <div className="mt-8 grid gap-8 lg:grid-cols-2">
        <section className="flex flex-col gap-3">
          <h2 className="section-title">Questions in this test</h2>
          {attached.length === 0 ? (
            <p className="text-sm text-muted-foreground">No questions yet — add some from your bank.</p>
          ) : (
            attached.map((q) => (
              <div className="card-base flex items-center justify-between gap-3 p-4" key={q.id}>
                <div className="flex items-center gap-3">
                  <Badge variant="secondary">{q.type}</Badge>
                  <div>
                    <p className="text-sm font-medium">{q.title}</p>
                    <p className="text-xs text-muted-foreground capitalize">{q.difficulty} · {q.points} pts</p>
                  </div>
                </div>
                {isDraft && (
                  <Button
                    aria-label="Remove question"
                    disabled={busy}
                    size="icon"
                    variant="ghost"
                    onClick={() => run(() => removeAssessmentQuestionAction(assessment.id, q.id), "Question removed.")}
                  >
                    <Trash2 />
                  </Button>
                )}
              </div>
            ))
          )}
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="section-title">Add from question bank</h2>
          {!isDraft ? (
            <p className="text-sm text-muted-foreground">Publish locks the question set. Move back to draft to edit.</p>
          ) : available.length === 0 ? (
            <p className="text-sm text-muted-foreground">All bank questions are already added.</p>
          ) : (
            <div className="flex flex-col gap-2">
              {available.map((q) => (
                <div className="card-base flex items-center justify-between gap-3 p-3" key={q.id}>
                  <div className="flex items-center gap-2">
                    <Badge variant="secondary">{q.type}</Badge>
                    <p className="text-sm">{q.title}</p>
                  </div>
                  <Button
                    disabled={busy}
                    size="sm"
                    variant="outline"
                    onClick={() => run(() => addAssessmentQuestionAction(assessment.id, q.id), "Question added.")}
                  >
                    <Plus /> Add
                  </Button>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>

      <section className="mt-10 flex flex-col gap-3">
        <h2 className="section-title">Assign to batches</h2>
        {batches.length === 0 ? (
          <p className="text-sm text-muted-foreground">Create a batch first to assign this assessment to a cohort.</p>
        ) : (
          <>
            <div className="flex flex-wrap gap-3">
              {batches.map((b) => (
                <Label className="card-base flex cursor-pointer items-center gap-2 p-3 font-normal" key={b.id}>
                  <Checkbox
                    checked={selectedBatches.includes(b.id)}
                    onCheckedChange={(c) => toggleBatch(b.id, Boolean(c))}
                  />
                  {b.name} <span className="text-xs text-muted-foreground">({b.member_count})</span>
                </Label>
              ))}
            </div>
            <div>
              <Button
                disabled={busy || selectedBatches.length === 0}
                onClick={() =>
                  run(() => assignAssessmentAction(assessment.id, "batch", selectedBatches), "Assigned to batches.")
                }
              >
                <Users /> Assign {selectedBatches.length > 0 ? `(${selectedBatches.length})` : ""}
              </Button>
            </div>
          </>
        )}
      </section>
    </main>
  );
}
