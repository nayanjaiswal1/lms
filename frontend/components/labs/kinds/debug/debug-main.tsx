"use client"

import { useState, type ReactNode } from "react"
import { AppWindow, Code2, ExternalLink, RefreshCw } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { DebugIdeFrame } from "@/components/labs/kinds/debug/debug-ide-frame"
import { LabPreviewPane } from "@/components/labs/lab-preview-pane"
import { useLabIde } from "@/hooks/use-lab-ide"

interface DebugMainProps {
  /** Left of the IDE/App tabs: panel toggle + progress. */
  leading: ReactNode
  /** Right end of the row: Check / Finish. */
  trailing: ReactNode
  sessionId: string
  labId: string
  idePort: number
  appPorts: number[]
}

/**
 * IDE / App tabs with the IDE reload + pop-out actions on the same row. Both
 * panes stay mounted (forceMount + hidden) so switching tabs never reloads
 * VS Code or the running app.
 */
export function DebugMain({ leading, trailing, sessionId, labId, idePort, appPorts }: DebugMainProps) {
  const [appPort, setAppPort] = useState(appPorts[0] ?? 0)
  const [reloadKey, setReloadKey] = useState(0)
  const ide = useLabIde(sessionId, idePort)

  return (
    <Tabs className="h-full min-h-0 gap-0" defaultValue="ide">
      <div className="flex shrink-0 items-center gap-1 border-b border-border bg-card px-2">
        {leading}
        <TabsList className="h-10 w-auto gap-1 overflow-visible bg-transparent p-0 sm:w-auto">
          <TabsTrigger className="h-8 flex-none px-2.5 text-xs lg:min-h-0 lg:min-w-0" value="ide">
            <Code2 aria-hidden className="h-4 w-4" />
            IDE
          </TabsTrigger>
          <TabsTrigger className="h-8 flex-none px-2.5 text-xs lg:min-h-0 lg:min-w-0" value="app">
            <AppWindow aria-hidden className="h-4 w-4" />
            App
          </TabsTrigger>
        </TabsList>
        <div className="ml-auto flex items-center gap-1">
          <Button
            aria-label="Reload IDE"
            className="touch-target-dense text-muted-foreground hover:text-foreground"
            size="sm"
            variant="ghost"
            onClick={() => setReloadKey((k) => k + 1)}
          >
            <RefreshCw aria-hidden className="h-3.5 w-3.5" />
          </Button>
          {ide.popOutUrl && (
            <Button
              className="touch-target-dense gap-1.5"
              size="sm"
              variant="ghost"
              onClick={() => void ide.popOut()}
            >
              <ExternalLink aria-hidden className="h-3.5 w-3.5" />
              <span className="max-sm:sr-only">Pop out</span>
            </Button>
          )}
          <div className="ml-1 flex items-center gap-2 border-l border-border pl-2">{trailing}</div>
        </div>
      </div>
      <TabsContent
        forceMount
        className="min-h-0 flex-1 data-[state=inactive]:hidden"
        value="ide"
      >
        <DebugIdeFrame
          ide={ide}
          key={reloadKey}
          labId={labId}
          reloaded={reloadKey > 0}
          sessionId={sessionId}
        />
      </TabsContent>
      <TabsContent
        forceMount
        className="min-h-0 flex-1 data-[state=inactive]:hidden"
        value="app"
      >
        <LabPreviewPane
          ports={appPorts.map((port) => ({ port }))}
          previewPort={appPort}
          sessionId={sessionId}
          onSelectPort={setAppPort}
        />
      </TabsContent>
    </Tabs>
  )
}
