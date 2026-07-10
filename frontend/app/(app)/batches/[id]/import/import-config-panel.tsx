"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { confirmImportAction } from "@/app/(app)/batches/actions";
import ROUTES from "@/lib/routes";
import type { Course } from "@/lib/server/courses";
import type { ImportMemberRow, OrgMemberSummary } from "@/lib/server/batches";

interface ImportConfig {
  courseIds: Set<string>;
  mentorIds: Set<string>;
  lockFullName: boolean;
}

interface ImportConfigPanelProps {
  batchId: string;
  rows: ImportMemberRow[];
  courses: Course[];
  orgMembers: OrgMemberSummary[];
  blockingCount: number;
}

export function ImportConfigPanel({ batchId, rows, courses, orgMembers, blockingCount }: ImportConfigPanelProps) {
  const [config, setConfig] = React.useState<ImportConfig>({
    courseIds: new Set(),
    mentorIds: new Set(),
    lockFullName: true,
  });
  const [submitting, setSubmitting] = React.useState(false);
  const router = useRouter();

  const mentors = orgMembers.filter((m) => m.role === "mentor" || m.role === "instructor" || m.role === "admin");

  function toggle(set: Set<string>, id: string): Set<string> {
    const next = new Set(set);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    return next;
  }

  async function confirm() {
    setSubmitting(true);
    const result = await confirmImportAction(batchId, {
      rows,
      course_ids: Array.from(config.courseIds),
      mentor_ids: Array.from(config.mentorIds),
      locked_fields: config.lockFullName ? ["full_name"] : [],
    });
    setSubmitting(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    router.push(`${ROUTES.batchImport(batchId)}?job=${result.data?.job_id}`);
  }

  return (
    <div className="border-t border-border pt-5 space-y-5">
      <h3 className="text-sm font-semibold text-foreground">Bulk configuration</h3>

      <div className="grid-responsive-2 gap-6">
        <fieldset className="space-y-2">
          <legend className="text-sm font-medium text-foreground mb-1">Assign courses</legend>
          {courses.length === 0 ? (
            <p className="text-sm text-muted-foreground">No courses available.</p>
          ) : (
            <div className="max-h-40 overflow-y-auto space-y-2">
              {courses.map((c) => (
                <label className="flex items-center gap-2 text-sm cursor-pointer" key={c.id}>
                  <Checkbox
                    checked={config.courseIds.has(c.id)}
                    onCheckedChange={() => setConfig((prev) => ({ ...prev, courseIds: toggle(prev.courseIds, c.id) }))}
                  />
                  {c.title}
                </label>
              ))}
            </div>
          )}
        </fieldset>

        <fieldset className="space-y-2">
          <legend className="text-sm font-medium text-foreground mb-1">Assign mentors</legend>
          {mentors.length === 0 ? (
            <p className="text-sm text-muted-foreground">No mentors available.</p>
          ) : (
            <div className="max-h-40 overflow-y-auto space-y-2">
              {mentors.map((m) => (
                <label className="flex items-center gap-2 text-sm cursor-pointer" key={m.user_id}>
                  <Checkbox
                    checked={config.mentorIds.has(m.user_id)}
                    onCheckedChange={() => setConfig((prev) => ({ ...prev, mentorIds: toggle(prev.mentorIds, m.user_id) }))}
                  />
                  {m.name}
                </label>
              ))}
            </div>
          )}
        </fieldset>
      </div>

      <div className="flex items-center gap-2">
        <Checkbox
          checked={config.lockFullName}
          id="lock-full-name"
          onCheckedChange={(checked) => setConfig((prev) => ({ ...prev, lockFullName: checked === true }))}
        />
        <Label className="text-sm font-normal cursor-pointer" htmlFor="lock-full-name">
          Students cannot edit their name after accepting
        </Label>
      </div>

      <div className="flex items-center justify-between gap-4 flex-wrap">
        {blockingCount > 0 && (
          <p className="text-sm text-destructive">
            Resolve {blockingCount} invalid/duplicate row{blockingCount === 1 ? "" : "s"} before confirming.
          </p>
        )}
        <Button
          className="px-5 py-2.5 ml-auto"
          disabled={submitting || blockingCount > 0 || rows.length === 0}
          onClick={confirm}
        >
          {submitting ? "Starting import…" : `Confirm Import (${rows.length})`}
        </Button>
      </div>
    </div>
  );
}
