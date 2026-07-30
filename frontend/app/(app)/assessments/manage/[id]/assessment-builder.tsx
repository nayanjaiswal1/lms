"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus, Trash2, Rocket, Copy, Link, ClipboardList, Settings } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { EditAssessmentSettingsForm } from "@/app/(app)/assessments/manage/[id]/edit-assessment-settings-form";
import {
  addAssessmentQuestionAction,
  removeAssessmentQuestionAction,
  publishAssessmentAction,
} from "@/app/(app)/assessments/manage/actions";
import { cn } from "@/lib/utils";
import type { Assessment, Question } from "@/lib/assessments/types";
import type { AssessmentQuestionFull } from "@/lib/assessments/server";

type BuilderTab = "questions" | "settings";

interface AssessmentBuilderProps {
  assessment: Assessment;
  attached: AssessmentQuestionFull[];
  bank: Question[];
}

export function AssessmentBuilder({ assessment, attached, bank }: AssessmentBuilderProps) {
  const router = useRouter();
  // Purely local, page-scoped UI state (which tab is open, whether a mutation
  // is in flight) — not URL-worthy, so kept in one combined useState rather
  // than a query param, to stay within the 2-useState component budget.
  const [ui, setUi] = React.useState<{ tab: BuilderTab; busy: boolean }>({ tab: "questions", busy: false });
  const tab = ui.tab;

  const attachedIds = new Set(attached.map((q) => q.question_id));
  const available = bank.filter((q) => !attachedIds.has(q.id));
  const isDraft = assessment.status === "draft";

  const run = async (fn: () => Promise<{ ok?: boolean; error?: string }>, success: string) => {
    setUi((s) => ({ ...s, busy: true }));
    const res = await fn();
    setUi((s) => ({ ...s, busy: false }));
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success(success);
    router.refresh();
  };

  return (
    <main className="page-container">
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
        {isDraft && tab === "questions" && (
          <Button
            disabled={ui.busy || attached.length === 0}
            onClick={() => run(() => publishAssessmentAction(assessment.id), "Assessment published.")}
          >
            <Rocket /> Publish
          </Button>
        )}
      </header>

      <nav aria-label="Assessment sections" className="mb-8 flex gap-1 border-b border-border">
        {(
          [
            { value: "questions", label: "Questions", Icon: ClipboardList },
            { value: "settings", label: "Test configuration", Icon: Settings },
          ] as const
        ).map(({ value, label, Icon }) => (
          <button
            aria-current={tab === value ? "page" : undefined}
            className={cn(
              "flex items-center gap-1.5 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors duration-fast",
              tab === value
                ? "border-primary text-primary"
                : "border-transparent text-muted-foreground hover:text-foreground",
            )}
            key={value}
            type="button"
            onClick={() => setUi((s) => ({ ...s, tab: value }))}
          >
            <Icon aria-hidden className="h-4 w-4" />
            {label}
          </button>
        ))}
      </nav>

      {tab === "settings" ? (
        <EditAssessmentSettingsForm assessment={assessment} />
      ) : (
      <>
      {assessment.parent_type === "hiring" && assessment.short_code && (
        <PublicLinkCard published={!isDraft} shortCode={assessment.short_code} />
      )}

      <div className="grid gap-8 lg:grid-cols-2">
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
                    disabled={ui.busy}
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
                    disabled={ui.busy}
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
      </>
      )}
    </main>
  );
}

function PublicLinkCard({ shortCode, published }: { shortCode: string; published: boolean }) {
  const base = process.env.NEXT_PUBLIC_APP_URL ?? "";
  const url = `${base}/hire/${shortCode}`;

  const copyLink = () => {
    void navigator.clipboard.writeText(url).then(() => toast.success("Link copied."));
  };

  return (
    <section className="mt-10 flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <Link aria-hidden className="h-5 w-5 text-primary" />
        <h2 className="section-title">Public candidate link</h2>
      </div>
      <div className="card-base flex flex-col gap-4 p-6">
        {!published ? (
          <p className="text-sm text-muted-foreground">
            Publish this assessment to activate the public link. Candidates won&apos;t be able to access it until it&apos;s published.
          </p>
        ) : (
          <p className="text-sm text-muted-foreground">
            Share this link with candidates. They enter their name and email then take the test — no account required.
          </p>
        )}
        <div className="flex items-center gap-2 rounded-lg border border-border bg-muted px-3 py-2">
          <span className="flex-1 truncate font-mono text-sm text-foreground">{url}</span>
          <Button
            aria-label="Copy link"
            disabled={!published}
            size="icon"
            variant="ghost"
            onClick={copyLink}
          >
            <Copy aria-hidden className="h-4 w-4" />
          </Button>
        </div>
        {published && (
          <a
            className="text-sm font-medium text-primary hover:underline"
            href={url}
            rel="noopener noreferrer"
            target="_blank"
          >
            Open link →
          </a>
        )}
      </div>
    </section>
  );
}
