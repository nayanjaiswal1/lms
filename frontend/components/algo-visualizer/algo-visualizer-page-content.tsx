"use client";

import { useState } from "react";
import { CodeEditor } from "@/components/shared/code-editor";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { narrateStep } from "@/lib/algo-visualizer/core/narrate";
import { DEFAULT_POINTER_NAMES } from "@/lib/algo-visualizer/core/pointer-detect";
import type { LanguageId } from "@/lib/algo-visualizer/core/types";
import { LANGUAGE_LIST, runTrace } from "@/lib/algo-visualizer/languages/registry";
import { SAMPLES } from "@/lib/algo-visualizer/samples";
import { AlgorithmHero } from "./algorithm-hero";
import { CodeView } from "./code-view";
import { ErrorBanner } from "./error-banner";
import { LivePreviewPanel } from "./live-preview-panel";
import { OutputPanel } from "./output-panel";
import { PlaybackControls } from "./playback-controls";
import { useVisualizerState } from "./use-visualizer-state";
import { VariablesPanel } from "./variables-panel";

interface SourceState {
  language: LanguageId;
  code: string;
  sampleName: string;
}

function firstSample(language: LanguageId): SourceState {
  const sample = SAMPLES[language][0];
  return { language, code: sample.code, sampleName: sample.name };
}

export function AlgoVisualizerPageContent() {
  const [source, setSource] = useState<SourceState>(() => firstSample("python"));
  const visualizer = useVisualizerState();
  const { state } = visualizer;

  const currentStep = state.steps[state.currentIndex] as (typeof state.steps)[number] | undefined;
  const prevStep = state.steps[state.currentIndex - 1] as (typeof state.steps)[number] | undefined;
  const visitedLines = new Set(state.steps.slice(0, state.currentIndex + 1).map((s) => s.line));
  const visibleOutput = state.outputLines.slice(0, currentStep?.outputLen ?? 0);
  const hasRun = state.steps.length > 0 || state.error !== null;
  const narration = currentStep
    ? narrateStep(prevStep?.locals, currentStep, source.code.split("\n")[currentStep.line - 1] ?? "")
    : { phase: "Idle", caption: "Run the code to begin." };
  const currentSample = SAMPLES[source.language].find((s) => s.name === source.sampleName);

  function handleLanguageChange(language: LanguageId) {
    setSource(firstSample(language));
  }

  function handleSampleChange(sampleName: string) {
    const sample = SAMPLES[source.language].find((s) => s.name === sampleName);
    if (sample) setSource({ language: source.language, code: sample.code, sampleName });
  }

  function handleRun() {
    visualizer.load(runTrace(source.code, source.language));
  }

  return (
    <div className="page-container flex flex-col gap-6">
      <div className="page-header">
        <h1 className="page-title">Algorithm Visualizer</h1>
        <p className="text-sm text-muted-foreground">
          Paste or write Python or JavaScript, then step through execution line by line.
        </p>
      </div>

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-wrap items-center gap-2">
          <Select value={source.language} onValueChange={(v) => handleLanguageChange(v as LanguageId)}>
            <SelectTrigger className="w-full sm:w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {LANGUAGE_LIST.map((lang) => (
                <SelectItem key={lang.id} value={lang.id}>
                  {lang.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select value={source.sampleName} onValueChange={handleSampleChange}>
            <SelectTrigger className="w-full sm:w-48">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {SAMPLES[source.language].map((sample) => (
                <SelectItem key={sample.name} value={sample.name}>
                  {sample.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <Button className="touch-target" onClick={handleRun}>
          Run & Visualize
        </Button>
      </div>

      {currentSample && <AlgorithmHero sample={currentSample} />}

      <div className="h-56">
        <CodeEditor height="100%" language={source.language} value={source.code} onChange={(v) => setSource({ ...source, code: v ?? "" })} />
      </div>

      {state.error && <ErrorBanner message={state.error} />}

      {hasRun && state.steps.length > 0 && (
        <div className="flex flex-col gap-6">
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <div className="h-80">
              <CodeView
                code={source.code}
                currentLine={currentStep?.line ?? null}
                language={source.language}
                visitedLines={visitedLines}
              />
            </div>
            <LivePreviewPanel
              caption={narration.caption}
              key={state.runId}
              locals={currentStep?.locals ?? {}}
              phase={narration.phase}
              pointerNames={DEFAULT_POINTER_NAMES}
              prevLocals={prevStep?.locals}
              stepIndex={state.currentIndex}
              steps={state.steps}
            />
          </div>

          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <VariablesPanel locals={currentStep?.locals ?? {}} />
            <div className="h-48">
              <OutputPanel lines={visibleOutput} />
            </div>
          </div>

          <PlaybackControls
            currentIndex={state.currentIndex}
            funcName={currentStep?.func ?? "<module>"}
            playing={state.playing}
            speedMs={state.speedMs}
            total={state.steps.length}
            onFirst={visualizer.first}
            onLast={visualizer.last}
            onNext={visualizer.next}
            onPrev={visualizer.prev}
            onSeek={visualizer.seek}
            onSpeedChange={visualizer.setSpeed}
            onTogglePlay={visualizer.togglePlay}
          />
        </div>
      )}
    </div>
  );
}
