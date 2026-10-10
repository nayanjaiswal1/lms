"use client"

import { KindEmbedNotice } from "@/components/labs/kinds/kind-embed-notice"
import { pickKindWorkspace } from "@/components/labs/kinds/workspace-registry"
import {
  StandardLabWorkspace,
  type LabWorkspaceContentProps,
} from "@/components/labs/standard-lab-workspace"

export { isLabAuthError } from "@/lib/labs/auth-error"
export type { LabVerifyBridge } from "@/components/labs/standard-lab-workspace"

/**
 * Entry point for a running lab's workspace. Lab kinds registered in
 * LAB_KIND_WORKSPACES (debug, ...) render their own full-screen workspace;
 * every other lab type keeps the standard task-panel + code/container
 * workspace. Hosts (the full-screen `LabEnvironment`, or an inline course
 * embed) provide their own chrome around it. Must be rendered inside a
 * `flex flex-col` container.
 */
export function LabWorkspaceContent(props: LabWorkspaceContentProps) {
  const { lab, session, kindBlock } = props
  const KindWorkspace = pickKindWorkspace(lab.lab_type, props.labUi)

  if (!KindWorkspace) return <StandardLabWorkspace {...props} />

  // Embeds (course notes) don't carry the kind block and can't fit an IDE.
  if (!kindBlock) return <KindEmbedNotice sessionId={session.id} />

  return (
    <KindWorkspace
      initialCompletions={props.initialCompletions}
      isResetting={props.isResetting}
      kindBlock={kindBlock}
      lab={lab}
      resetNonce={props.resetNonce ?? 0}
      resetsLeft={props.resetsLeft}
      session={session}
      onAuthExpiredChange={props.onAuthExpiredChange}
      onLogin={props.onLogin}
      onReset={props.onReset}
      onScoreChange={props.onScoreChange}
    />
  )
}
