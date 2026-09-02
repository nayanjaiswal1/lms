"use client";

import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { FileText, Globe } from "lucide-react";
import { cn } from "@/lib/utils";
import type { CourseDraft } from "@/lib/courses/draft-types";

interface SettingsTabProps {
  status:            CourseDraft["status"];
  onChange:          (status: CourseDraft["status"]) => void;
  disableDraft?:     boolean;
  disableCodeRun:    boolean;
  onDisableCodeRunChange: (value: boolean) => void;
  disableReflection: boolean;
  onDisableReflectionChange: (value: boolean) => void;
}

export function SettingsTab({
  status,
  onChange,
  disableDraft,
  disableCodeRun,
  onDisableCodeRunChange,
  disableReflection,
  onDisableReflectionChange,
}: SettingsTabProps) {
  return (
    <div className="flex flex-col gap-8 max-w-lg">
      {/* Publication status */}
      <div className="flex flex-col gap-3">
        <Label className="text-base font-semibold">Publication status</Label>
        <RadioGroup className="flex flex-col gap-3" value={status} onValueChange={(v) => onChange(v as CourseDraft["status"])}>
          <label className={cn(
            "flex items-start gap-3 rounded-lg border border-border p-4 transition-colors has-[[data-state=checked]]:border-primary has-[[data-state=checked]]:bg-primary/5",
            disableDraft ? "cursor-not-allowed opacity-50" : "cursor-pointer",
          )} htmlFor="status-draft">
            <RadioGroupItem className="mt-0.5" disabled={disableDraft} id="status-draft" value="draft" />
            <div className="flex flex-col gap-0.5">
              <div className="flex items-center gap-2">
                <FileText aria-hidden className="h-4 w-4 text-muted-foreground" />
                <span className="text-sm font-medium">Save as draft</span>
              </div>
              <p className="text-xs text-muted-foreground">
                {disableDraft
                  ? "This course is already published and can't be unpublished here."
                  : "Only you can see this course. Students cannot enroll until you publish."}
              </p>
            </div>
          </label>

          <label className="flex cursor-pointer items-start gap-3 rounded-lg border border-border p-4 transition-colors has-[[data-state=checked]]:border-primary has-[[data-state=checked]]:bg-primary/5" htmlFor="status-published">
            <RadioGroupItem className="mt-0.5" id="status-published" value="published" />
            <div className="flex flex-col gap-0.5">
              <div className="flex items-center gap-2">
                <Globe aria-hidden className="h-4 w-4 text-muted-foreground" />
                <span className="text-sm font-medium">Publish immediately</span>
              </div>
              <p className="text-xs text-muted-foreground">
                The course goes live as soon as it is created. Students can enroll right away.
              </p>
            </div>
          </label>
        </RadioGroup>
      </div>

      {/* Code runner */}
      <div className="flex flex-col gap-3">
        <Label className="text-base font-semibold">Code blocks</Label>
        <div className="flex items-start gap-3 rounded-lg border border-border p-4">
          <Checkbox
            checked={disableCodeRun}
            className="mt-0.5"
            id="disable-code-run"
            onCheckedChange={(v) => onDisableCodeRunChange(Boolean(v))}
          />
          <div className="flex flex-col gap-0.5">
            <Label className="cursor-pointer font-normal" htmlFor="disable-code-run">
              Lock the Run button on every code block
            </Label>
            <p className="text-xs text-muted-foreground">
              Students can still read and copy code, but never execute it in this course —
              use this when a snippet isn&apos;t meant to be run standalone (fragments, exploit
              examples, config excerpts).
            </p>
          </div>
        </div>
      </div>

      {/* Reflection */}
      <div className="flex flex-col gap-3">
        <Label className="text-base font-semibold">Lesson reflection</Label>
        <div className="flex items-start gap-3 rounded-lg border border-border p-4">
          <Checkbox
            checked={disableReflection}
            className="mt-0.5"
            id="disable-reflection"
            onCheckedChange={(v) => onDisableReflectionChange(Boolean(v))}
          />
          <div className="flex flex-col gap-0.5">
            <Label className="cursor-pointer font-normal" htmlFor="disable-reflection">
              Hide the Reflect box on notes lessons
            </Label>
            <p className="text-xs text-muted-foreground">
              By default, students write a short reflection on every notes lesson and must save it
              before marking the lesson complete. Turn this on to skip reflection for this course.
            </p>
          </div>
        </div>
      </div>

      {/* Video privacy note */}
      <div className="rounded-md border border-border bg-muted/50 p-4 text-sm">
        <p className="font-medium mb-1">Uploaded video privacy</p>
        <p className="text-muted-foreground text-xs leading-relaxed">
          All videos you upload are restricted to enrolled students only.
          The browser never receives the raw storage URL — it receives a short-lived signed URL
          (15-minute expiry) generated per request. This prevents link sharing or unauthorized downloads.
        </p>
      </div>
    </div>
  );
}
