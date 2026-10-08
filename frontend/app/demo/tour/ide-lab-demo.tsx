"use client";

import { useState } from "react";
import { FileCode2, FileText, Files, Play, RotateCcw } from "lucide-react";

import { Button } from "@/components/ui/button";
import { CodeEditor } from "@/components/shared/code-editor";
import { LabTaskPanel } from "@/app/demo/tour/lab-shell";
import { LivePreview } from "@/app/demo/tour/live-preview";
import { DEMO_IDE_LAB as LAB } from "@/app/demo/tour/mock-data";
import { cn } from "@/lib/utils";

interface IdeLabDemoProps {
  nonce: string;
}

interface Workspace {
  files: Record<string, string>;
  active: string;
}

interface Execution {
  files: Record<string, string>;
  run: number;
  results: boolean[] | null;
}

const FILE_ICONS: Record<string, typeof FileText> = { "index.html": FileText, "styles.css": FileText, "app.js": FileCode2 };
const LANGUAGES: Record<string, string> = { "index.html": "html", "styles.css": "css", "app.js": "javascript" };
const INITIAL_WORKSPACE: Workspace = { files: LAB.files, active: "app.js" };

// VS Code-style workbench: explorer, tabbed Monaco editor, live preview and a
// terminal panel. The real debug labs embed openvscode-server in a container;
// this runs the same edit → run → grade loop entirely in the browser.
export function IdeLabDemo({ nonce }: IdeLabDemoProps) {
  const [ws, setWs] = useState<Workspace>(INITIAL_WORKSPACE);
  const [exec, setExec] = useState<Execution>({ files: LAB.files, run: 0, results: null });

  const passed = new Set(LAB.tasks.filter((_, i) => exec.results?.[i] === true).map((t) => t.id));
  const allPassed = passed.size === LAB.tasks.length;
  const names = Object.keys(ws.files);

  const terminal =
    exec.run === 0
      ? "$ Press Run (▶) to execute the project."
      : exec.results === null
        ? "$ node app.js … running"
        : ["$ run-checks", ...LAB.tasks.map((t, i) => `${exec.results?.[i] ? "PASS" : "FAIL"}  ${t.title}`)].join("\n");

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1>{LAB.title}</h1>
        <p className="text-muted-foreground">{LAB.brief}</p>
      </div>

      <div className="grid gap-4 lg:grid-cols-[18rem_1fr]">
        <LabTaskPanel hints={LAB.hints} passed={passed} tasks={LAB.tasks} />

        <div className="flex min-w-0 flex-col overflow-hidden rounded-lg border border-border bg-card">
          <div className="flex items-center justify-between gap-2 border-b border-border bg-muted px-3 py-2">
            <p className="truncate font-mono text-xs text-muted-foreground">mindforge-lab — {ws.active}</p>
            <div className="flex gap-2">
              <Button
                aria-label="Reset workspace"
                size="sm"
                variant="outline"
                onClick={() => { setWs(INITIAL_WORKSPACE); setExec((e) => ({ files: LAB.files, run: e.run + 1, results: null })); }}
              >
                <RotateCcw aria-hidden className="h-3.5 w-3.5" />
              </Button>
              <Button size="sm" onClick={() => setExec((e) => ({ files: ws.files, run: e.run + 1, results: null }))}>
                <Play aria-hidden className="mr-1.5 h-3.5 w-3.5" />
                Run
              </Button>
            </div>
          </div>

          <div className="grid min-w-0 md:grid-cols-[12rem_1fr]">
            <aside aria-label="Explorer" className="border-b border-border bg-muted/50 p-2 md:border-b-0 md:border-r">
              <p className="mb-1 flex items-center gap-2 px-2 py-1 text-xs font-medium uppercase tracking-wider text-muted-foreground">
                <Files aria-hidden className="h-3.5 w-3.5" />
                Explorer
              </p>
              {names.map((name) => {
                const Icon = FILE_ICONS[name] ?? FileText;
                return (
                  <Button
                    aria-current={name === ws.active ? "true" : undefined}
                    className={cn(
                      "flex h-auto w-full items-center justify-start gap-2 rounded px-2 py-1.5 font-mono text-xs",
                      name === ws.active ? "bg-primary/10 text-primary" : "text-muted-foreground hover:text-foreground",
                    )}
                    key={name}
                    type="button"
                    variant="unstyled"
                    onClick={() => setWs((w) => ({ ...w, active: name }))}
                  >
                    <Icon aria-hidden className="h-3.5 w-3.5 shrink-0" />
                    {name}
                  </Button>
                );
              })}
            </aside>

            <div className="flex min-w-0 flex-col">
              <div className="flex overflow-x-auto border-b border-border" role="tablist">
                {names.map((name) => (
                  <Button
                    aria-selected={name === ws.active}
                    className={cn(
                      "h-auto rounded-none border-r border-border px-4 py-2 font-mono text-xs",
                      name === ws.active ? "bg-background text-foreground" : "bg-muted/50 text-muted-foreground",
                    )}
                    key={name}
                    role="tab"
                    type="button"
                    variant="unstyled"
                    onClick={() => setWs((w) => ({ ...w, active: name }))}
                  >
                    {name}
                  </Button>
                ))}
              </div>
              <CodeEditor
                height="320px"
                language={LANGUAGES[ws.active]}
                tabSize={2}
                value={ws.files[ws.active]}
                onChange={(v) => setWs((w) => ({ ...w, files: { ...w.files, [w.active]: v ?? "" } }))}
              />
            </div>
          </div>

          <div className="grid border-t border-border md:grid-cols-2">
            <div className="flex min-w-0 flex-col gap-2 p-4">
              <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">Preview</p>
              <LivePreview
                css={exec.files["styles.css"]}
                harness={LAB.harness}
                html={exec.files["index.html"]}
                nonce={nonce}
                runKey={exec.run}
                script={exec.files["app.js"]}
                onResults={(results) => setExec((e) => ({ ...e, results }))}
              />
            </div>
            <div className="flex min-w-0 flex-col gap-2 border-t border-border p-4 md:border-l md:border-t-0">
              <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">Terminal</p>
              <pre className="min-h-64 flex-1 overflow-x-auto whitespace-pre rounded-md bg-muted p-3 font-mono text-xs" role="log">
                {terminal}
              </pre>
              {allPassed && <p className="text-sm text-success">All tasks passed — lab complete.</p>}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
