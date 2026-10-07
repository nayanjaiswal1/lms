import type { ReactNode } from "react"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

interface DebugSidePanelProps {
  passed: number
  total: number
  ticket: ReactNode
  checks: ReactNode
  writeup: ReactNode
}

/** Ticket / Checks / Write-up as tabs — one section visible at a time. */
export function DebugSidePanel({ passed, total, ticket, checks, writeup }: DebugSidePanelProps) {
  return (
    <Tabs className="min-h-0 flex-1 gap-0" defaultValue="ticket">
      <TabsList className="h-9 w-full shrink-0 gap-0 rounded-none bg-transparent p-0 sm:w-full">
        <TabsTrigger className="h-9 rounded-none border-0 border-b-2 text-xs data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:shadow-none lg:min-h-0 lg:min-w-0" value="ticket">Ticket</TabsTrigger>
        <TabsTrigger className="h-9 rounded-none border-0 border-b-2 text-xs data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:shadow-none lg:min-h-0 lg:min-w-0" value="checks">
          Checks
          <span className="text-xs tabular-nums text-muted-foreground">
            {passed}/{total}
          </span>
        </TabsTrigger>
        <TabsTrigger className="h-9 rounded-none border-0 border-b-2 text-xs data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:shadow-none lg:min-h-0 lg:min-w-0" value="writeup">Write-up</TabsTrigger>
      </TabsList>
      <div className="min-h-0 flex-1 overflow-y-auto overflow-x-hidden p-3">
        <TabsContent value="ticket">{ticket}</TabsContent>
        <TabsContent value="checks">{checks}</TabsContent>
        <TabsContent value="writeup">{writeup}</TabsContent>
      </div>
    </Tabs>
  )
}
