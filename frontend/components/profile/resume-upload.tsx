"use client"

import { useActionState } from "react"
import { FileText, Sparkles, Upload, CheckCircle2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"
import type { ResumeExtract } from "@/lib/profile/types"

interface ParseState {
  data?: ResumeExtract
  error?: string
}

interface ApplyState {
  error?: string
  success?: boolean
}

interface Props {
  parseAction: (prev: unknown, formData: FormData) => Promise<ParseState>
  applyAction: (prev: unknown, formData: FormData) => Promise<ApplyState>
}

export function ResumeUpload({ parseAction, applyAction }: Props) {
  const [parseState, parseDispatch, parsePending] = useActionState(parseAction, {})
  const [applyState, applyDispatch, applyPending] = useActionState(applyAction, {})

  const extracted = parseState.data

  return (
    <section aria-labelledby="resume-heading" className="card-base p-6 space-y-5">
      <div className="flex items-center gap-2">
        <h2 className="text-lg font-semibold text-foreground" id="resume-heading">
          Resume Import
        </h2>
        <span className="ai-badge">AI</span>
      </div>

      <p className="text-sm text-muted-foreground">
        Upload your PDF resume and Claude will extract your name, bio, role, skills, and social
        links automatically.
      </p>

      {/* Step 1 — upload form */}
      <form action={parseDispatch} className="space-y-4">
        <div className="space-y-1.5">
          <Label htmlFor="resume-file">Resume (PDF, max 5 MB)</Label>
          <label
            htmlFor="resume-file"
            className="flex flex-col items-center justify-center gap-2 w-full min-h-[120px] rounded-lg border-2 border-dashed border-border bg-muted/40 cursor-pointer transition-colors hover:border-primary hover:bg-muted/60"
          >
            <Upload className="h-6 w-6 text-muted-foreground" aria-hidden />
            <span className="text-sm text-muted-foreground">Click to choose a PDF file</span>
            <input
              id="resume-file"
              name="resume"
              type="file"
              accept="application/pdf"
              className="sr-only"
            />
          </label>
        </div>

        {parseState.error && (
          <p className="text-sm text-destructive">{parseState.error}</p>
        )}

        <Button type="submit" disabled={parsePending} className="px-5 py-2.5">
          {parsePending ? (
            "Parsing…"
          ) : (
            <>
              <Sparkles className="h-4 w-4 mr-2" aria-hidden />
              Parse Resume
            </>
          )}
        </Button>
      </form>

      {/* Step 2 — extracted preview + apply */}
      {extracted && (
        <div className="ai-surface rounded-lg p-4 space-y-4">
          <div className="flex items-center gap-2">
            <FileText className="h-4 w-4 text-ai" aria-hidden />
            <p className="text-sm font-medium text-foreground">Extracted from your resume</p>
          </div>

          <dl className="space-y-2 text-sm">
            {extracted.name && (
              <ExtractRow label="Name" value={extracted.name} />
            )}
            {extracted.current_role && (
              <ExtractRow label="Role" value={extracted.current_role} />
            )}
            {extracted.years_of_experience !== undefined && (
              <ExtractRow
                label="Experience"
                value={`${extracted.years_of_experience} year${extracted.years_of_experience !== 1 ? "s" : ""}`}
              />
            )}
            {extracted.bio && (
              <ExtractRow label="Bio" value={extracted.bio} />
            )}
            {extracted.skills && extracted.skills.length > 0 && (
              <div className="flex gap-2 flex-wrap pt-1">
                {extracted.skills.map((s) => (
                  <span
                    key={s.skill_name}
                    className={`difficulty-${s.skill_level} text-xs px-2 py-0.5 rounded-full`}
                  >
                    {s.skill_name}
                  </span>
                ))}
              </div>
            )}
          </dl>

          <form action={applyDispatch}>
            <input
              type="hidden"
              name="extract"
              value={JSON.stringify(extracted)}
              readOnly
            />
            {applyState.error && (
              <p className="text-sm text-destructive mb-2">{applyState.error}</p>
            )}
            {applyState.success ? (
              <div className="flex items-center gap-1.5 text-sm text-foreground">
                <CheckCircle2 className="h-4 w-4 text-primary" aria-hidden />
                Applied to your profile.
              </div>
            ) : (
              <Button
                type="submit"
                disabled={applyPending}
                variant="outline"
                className="px-5 py-2.5"
              >
                {applyPending ? "Applying…" : "Apply to Profile"}
              </Button>
            )}
          </form>
        </div>
      )}
    </section>
  )
}

function ExtractRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex gap-2">
      <dt className="w-24 shrink-0 text-muted-foreground">{label}</dt>
      <dd className="text-foreground">{value}</dd>
    </div>
  )
}
