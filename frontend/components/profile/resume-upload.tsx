"use client"

import { useActionState, useState } from "react"
import { FileText, Sparkles, Upload, CheckCircle2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { SettingsSection } from "@/components/profile/settings-section"
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
  const [fileName, setFileName] = useState<string | null>(null)

  const extracted = parseState.data

  return (
    <SettingsSection
      description="Upload a PDF resume and AI fills in your name, bio, role, skills and links. You review everything before it's applied."
      id="resume"
      title={<>Import from resume <span className="ai-badge">AI</span></>}
    >
      <form action={parseDispatch} className="space-y-4">
        <label
          className="upload-dropzone w-full cursor-pointer has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-ring"
          htmlFor="resume-file"
        >
          {fileName ? (
            <FileText aria-hidden className="h-6 w-6 text-foreground" />
          ) : (
            <Upload aria-hidden className="h-6 w-6 text-muted-foreground" />
          )}
          <span className="max-w-full break-all text-sm font-medium text-foreground">
            {fileName ?? "Choose a PDF file"}
          </span>
          <span className="text-xs text-muted-foreground">
            {fileName ? "Click to pick a different file" : "PDF only, up to 5 MB"}
          </span>
          <input
            accept="application/pdf"
            className="sr-only"
            id="resume-file"
            name="resume"
            type="file"
            onChange={(e) => setFileName(e.target.files?.[0]?.name ?? null)}
          />
        </label>

        {parseState.error && (
          <p className="text-sm text-destructive" role="alert">{parseState.error}</p>
        )}

        <div className="flex justify-end">
          <Button aria-busy={parsePending} className="w-full sm:w-auto" disabled={parsePending} size="lg" type="submit" variant="outline">
            <Sparkles aria-hidden className="h-4 w-4 text-ai" />
            {parsePending ? "Reading resume…" : "Extract details"}
          </Button>
        </div>
      </form>

      {extracted && (
        <div className="ai-surface mt-6 space-y-4 rounded-lg p-4" aria-live="polite">
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
              <p className="mb-2 text-sm text-destructive" role="alert">{applyState.error}</p>
            )}
            {applyState.success ? (
              <output className="flex items-center gap-1.5 text-sm text-foreground">
                <CheckCircle2 aria-hidden className="h-4 w-4 text-primary" />
                Applied to your profile.
              </output>
            ) : (
              <Button
                aria-busy={applyPending}
                className="w-full sm:w-auto"
                disabled={applyPending}
                size="lg"
                type="submit"
              >
                {applyPending ? "Applying…" : "Apply to profile"}
              </Button>
            )}
          </form>
        </div>
      )}
    </SettingsSection>
  )
}

function ExtractRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 sm:flex-row sm:gap-2">
      <dt className="shrink-0 text-muted-foreground sm:w-24">{label}</dt>
      <dd className="min-w-0 text-foreground">{value}</dd>
    </div>
  )
}
