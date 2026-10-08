"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { LabTaskPanel } from "@/app/demo/tour/lab-shell";
import {
  INITIAL_DOCKER_STATE,
  dockerTasksPassed,
  runDockerCommand,
  type DockerState,
} from "@/app/demo/tour/docker-engine";
import { DEMO_DOCKER_LAB as LAB } from "@/app/demo/tour/mock-data";

const PROMPT = "labuser@lab:~$";
const WELCOME = "Type 'help' to see the supported commands.";

interface Terminal {
  docker: DockerState;
  lines: string[];
}

const INITIAL_TERMINAL: Terminal = { docker: INITIAL_DOCKER_STATE, lines: [WELCOME] };

// Browser terminal over an in-memory Docker simulator. The real labs attach to
// a sandboxed container over WebSocket; anonymous visitors can't start one.
export function DockerLabDemo() {
  const [term, setTerm] = useState<Terminal>(INITIAL_TERMINAL);
  const [input, setInput] = useState("");
  const passed = dockerTasksPassed(term.docker);
  const allPassed = passed.size === LAB.tasks.length;

  function submit(e: React.FormEvent) {
    e.preventDefault();
    const line = input;
    setInput("");
    if (line.trim() === "clear") {
      setTerm((t) => ({ ...t, lines: [] }));
      return;
    }
    setTerm((t) => {
      const { state, output } = runDockerCommand(t.docker, line);
      return { docker: state, lines: [...t.lines, `${PROMPT} ${line}`, ...(output ? [output] : [])] };
    });
  }

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1>{LAB.title}</h1>
        <p className="text-muted-foreground">{LAB.brief}</p>
      </div>

      <div className="grid gap-4 lg:grid-cols-[18rem_1fr]">
        <LabTaskPanel hints={LAB.hints} passed={passed} tasks={LAB.tasks} />

        <section aria-label="Terminal" className="card-base flex min-w-0 flex-col gap-3 p-5">
          <div
            aria-live="polite"
            className="min-h-64 overflow-x-auto whitespace-pre rounded-md bg-muted p-4 font-mono text-sm"
            role="log"
          >
            {term.lines.join("\n")}
          </div>
          <form className="flex items-center gap-2" onSubmit={submit}>
            <span className="hidden font-mono text-sm text-muted-foreground sm:block">{PROMPT}</span>
            <Input
              aria-label="Terminal command"
              autoComplete="off"
              className="font-mono"
              placeholder="docker run -d --name web -p 8080:80 nginx"
              spellCheck={false}
              value={input}
              onChange={(e) => setInput(e.target.value)}
            />
            <Button size="sm" type="submit">Run</Button>
          </form>
          <div className="flex items-center justify-between gap-2">
            <p className={allPassed ? "text-sm text-success" : "text-sm text-muted-foreground"}>
              {allPassed ? "All tasks passed — lab complete." : "Tasks check off automatically as you run commands."}
            </p>
            <Button size="sm" variant="outline" onClick={() => setTerm(INITIAL_TERMINAL)}>Reset</Button>
          </div>
        </section>
      </div>
    </div>
  );
}
