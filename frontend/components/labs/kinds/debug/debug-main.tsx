"use client"

import { useState } from "react"
import { AppWindow, Code2 } from "lucide-react"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { DebugIdeFrame } from "@/components/labs/kinds/debug/debug-ide-frame"
import { LabPreviewPane } from "@/components/labs/lab-preview-pane"

interface DebugMainProps {
  sessionId: string
  idePort: number
  appPorts: number[]
}

/**
 * IDE / App tabs. Both panes stay mounted (forceMount + hidden) so switching
 * tabs never reloads VS Code or the running app.
 */
export function DebugMain({ sessionId, idePort, appPorts }: DebugMainProps) {
  const [appPort, setAppPort] = useState(appPorts[0] ?? 0)

  return (
    <Tabs className="h-full min-h-0 gap-0" defaultValue="ide">
      <TabsList className="w-full shrink-0 rounded-none sm:w-full">
        <TabsTrigger value="ide">
          <Code2 aria-hidden className="h-4 w-4" />
          IDE
        </TabsTrigger>
        <TabsTrigger value="app">
          <AppWindow aria-hidden className="h-4 w-4" />
          App
        </TabsTrigger>
      </TabsList>
      <TabsContent
        forceMount
        className="min-h-0 flex-1 data-[state=inactive]:hidden"
        value="ide"
      >
        <DebugIdeFrame idePort={idePort} sessionId={sessionId} />
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
