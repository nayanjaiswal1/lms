"use client";

import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { FileText, Globe } from "lucide-react";
import type { CourseDraft } from "@/lib/courses/draft-types";

interface SettingsTabProps {
  status:   CourseDraft["status"];
  onChange: (status: CourseDraft["status"]) => void;
}

export function SettingsTab({ status, onChange }: SettingsTabProps) {
  return (
    <div className="flex flex-col gap-8 max-w-lg">
      {/* Publication status */}
      <div className="flex flex-col gap-3">
        <Label className="text-base font-semibold">Publication status</Label>
        <RadioGroup value={status} onValueChange={(v) => onChange(v as CourseDraft["status"])} className="flex flex-col gap-3">
          <label className="flex cursor-pointer items-start gap-3 rounded-lg border border-border p-4 transition-colors has-[[data-state=checked]]:border-primary has-[[data-state=checked]]:bg-primary/5">
            <RadioGroupItem value="draft" id="status-draft" className="mt-0.5" />
            <div className="flex flex-col gap-0.5">
              <div className="flex items-center gap-2">
                <FileText className="h-4 w-4 text-muted-foreground" aria-hidden />
                <span className="text-sm font-medium">Save as draft</span>
              </div>
              <p className="text-xs text-muted-foreground">
                Only you can see this course. Students cannot enroll until you publish.
              </p>
            </div>
          </label>

          <label className="flex cursor-pointer items-start gap-3 rounded-lg border border-border p-4 transition-colors has-[[data-state=checked]]:border-primary has-[[data-state=checked]]:bg-primary/5">
            <RadioGroupItem value="published" id="status-published" className="mt-0.5" />
            <div className="flex flex-col gap-0.5">
              <div className="flex items-center gap-2">
                <Globe className="h-4 w-4 text-muted-foreground" aria-hidden />
                <span className="text-sm font-medium">Publish immediately</span>
              </div>
              <p className="text-xs text-muted-foreground">
                The course goes live as soon as it is created. Students can enroll right away.
              </p>
            </div>
          </label>
        </RadioGroup>
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
