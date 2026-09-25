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
        <h2 className="subsection-title text-foreground" id="resume-heading">
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
            className="upload-dropzone w-full min-h-[120px] cursor-pointer hover:border-primary"
            htmlFor="resume-file"
          >
            <Upload aria-hidden className="h-6 w-6 text-muted-foreground" />
            <span className="text-sm text-muted-foreground">Click to choose a PDF file</span>
            <input
              accept="application/pdf"
              className="sr-only"
              id="resume-file"
              name="resume"
              type="file"
            />
          </label>
        </div>

        {parseState.error && (
          <p className="text-sm text-destructive">{parseState.error}</p>
        )}

        <Button className="px-5 py-2.5" disabled={parsePending} type="submit">
          {parsePending ? (
            "Parsing…"
          ) : (
            <>
              <Sparkles aria-hidden className="h-4 w-4 mr-2" />
              Parse Resume
            </>
          )}
        </Button>
      </form>

      {/* Step 2 — extracted preview + apply */}
      {extracted && (
        <div className="ai-surface rounded-lg p-4 space-y-4">
          <div className="flex items-center gap-2">
            <FileText aria-hidden className="h-4 w-4 text-ai" />
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
                    className={`difficulty-${s.skill_level} text-xs px-2 py-0.5 rounded-full`}
                    key={s.skill_name}
                  >
                    {s.skill_name}
                  </span>
                ))}
              </div>
            )}
          </dl>

          <form action={applyDispatch}>
            <input
              readOnly
              name="extract"
              type="hidden"
              value={JSON.stringify(extracted)}
            />
            {applyState.error && (
              <p className="text-sm text-destructive mb-2">{applyState.error}</p>
            )}
            {applyState.success ? (
              <div className="flex items-center gap-1.5 text-sm text-foreground">
                <CheckCircle2 aria-hidden className="h-4 w-4 text-primary" />
                Applied to your profile.
              </div>
            ) : (
              <Button
                className="px-5 py-2.5"
                disabled={applyPending}
                type="submit"
                variant="outline"
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
