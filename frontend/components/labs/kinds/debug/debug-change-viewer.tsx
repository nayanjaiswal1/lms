"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { DebugDiffView } from "@/components/labs/kinds/debug/debug-diff-view"
import { parseUnifiedDiff, type DiffFile } from "@/lib/labs/kinds/diff"
import { cn } from "@/lib/utils"

interface DebugChangeViewerProps {
  /** The student's own diff; empty when the workspace is gone. */
  studentDiff: string
  referenceDiff: string
}

const EMPTY_STUDENT = "Your workspace changes are no longer available."
const EMPTY_REFERENCE = "No reference diff for this scenario."

function rowsFor(files: DiffFile[], path: string) {
  return files.find((f) => f.path === path)?.rows ?? []
}

/** Per-file diff viewer: Your fix / Reference fix, plus side-by-side on wide screens. */
export function DebugChangeViewer({ studentDiff, referenceDiff }: DebugChangeViewerProps) {
  const student = parseUnifiedDiff(studentDiff)
  const reference = parseUnifiedDiff(referenceDiff)
  const paths = [...new Set([...student, ...reference].map((f) => f.path))]
  const [picked, setPicked] = useState(paths[0] ?? "")
  const path = paths.includes(picked) ? picked : (paths[0] ?? "")

  return (
    <Tabs className="gap-3" defaultValue="student">
      <TabsList className="w-full sm:w-fit">
        <TabsTrigger value="student">Your fix</TabsTrigger>
        <TabsTrigger value="reference">Reference fix</TabsTrigger>
        <TabsTrigger className="hidden xl:inline-flex" value="side">
          Side by side
        </TabsTrigger>
      </TabsList>

      {paths.length > 1 && (
        <ul aria-label="Changed files" className="flex flex-wrap gap-1">
          {paths.map((p) => (
            <li className="min-w-0" key={p}>
              <Button
                aria-pressed={p === path}
                className={cn("min-h-11 max-w-full font-mono text-xs", p === path && "bg-accent text-accent-foreground")}
                size="sm"
                variant="ghost"
                onClick={() => setPicked(p)}
              >
                <span className="truncate">{p}</span>
              </Button>
            </li>
          ))}
        </ul>
      )}
      {path && <p className="break-all font-mono text-xs text-muted-foreground">{path}</p>}

      <TabsContent value="student">
        <DebugDiffView emptyMessage={EMPTY_STUDENT} label="Your fix" rows={rowsFor(student, path)} />
      </TabsContent>
      <TabsContent value="reference">
        <DebugDiffView emptyMessage={EMPTY_REFERENCE} label="Reference fix" rows={rowsFor(reference, path)} />
      </TabsContent>
      <TabsContent className="hidden gap-4 data-[state=active]:xl:grid xl:grid-cols-2" value="side">
        <DebugDiffView emptyMessage={EMPTY_STUDENT} label="Your fix" rows={rowsFor(student, path)} />
        <DebugDiffView emptyMessage={EMPTY_REFERENCE} label="Reference fix" rows={rowsFor(reference, path)} />
      </TabsContent>
    </Tabs>
  )
}
