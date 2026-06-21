"use client";

import * as React from "react";
import { Mic, MicOff, CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

const MAX_CHARS = 50_000;

interface TranscriptInputProps {
  prompt: string;
  value: string;
  onChange: (text: string) => void;
  onSave: (text: string) => void;
}

interface SpeechRec {
  continuous: boolean;
  interimResults: boolean;
  onresult: ((event: SpeechRecognitionEvent) => void) | null;
  onerror: (() => void) | null;
  onend: (() => void) | null;
  start: () => void;
  stop: () => void;
}

function getSpeechRecognition(): (new () => SpeechRec) | null {
  if (typeof window === "undefined") return null;
  const w = window as unknown as Record<string, unknown>;
  return (w["SpeechRecognition"] ?? w["webkitSpeechRecognition"] ?? null) as
    | (new () => SpeechRec)
    | null;
}

// All mutable UI state in one object so the component stays within the 2-useState
// rule. hasSpeech starts false (SSR-safe) and is set after mount so the mic
// button only appears after hydration — avoiding a server/client mismatch.
interface TranscriptUIState {
  listening: boolean;
  hasSpeech: boolean;
  saved: boolean;
}

function useTranscriptInput(
  value: string,
  onChange: (text: string) => void,
  onSave: (text: string) => void,
) {
  const [ui, setUI] = React.useState<TranscriptUIState>({
    listening: false,
    hasSpeech: false,
    saved: false,
  });
  const timerRef = React.useRef<ReturnType<typeof setTimeout> | null>(null);
  const recognitionRef = React.useRef<SpeechRec | null>(null);

  React.useEffect(() => {
    setUI((s) => ({ ...s, hasSpeech: getSpeechRecognition() !== null }));
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
      recognitionRef.current?.stop();
    };
  }, []);

  const handleChange = (text: string) => {
    if (text.length > MAX_CHARS) return;
    onChange(text);
    setUI((s) => ({ ...s, saved: false }));
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => {
      onSave(text);
      setUI((s) => ({ ...s, saved: true }));
    }, 600);
  };

  const toggleMic = () => {
    const Ctor = getSpeechRecognition();
    if (!Ctor) return;

    if (ui.listening) {
      recognitionRef.current?.stop();
      setUI((s) => ({ ...s, listening: false }));
      return;
    }

    const rec = new Ctor();
    rec.continuous = true;
    rec.interimResults = true;
    rec.onresult = (event: SpeechRecognitionEvent) => {
      let final = "";
      for (let i = event.resultIndex; i < event.results.length; i++) {
        if (event.results[i].isFinal) final += event.results[i][0].transcript + " ";
      }
      if (final) handleChange(value + final);
    };
    rec.onerror = () => setUI((s) => ({ ...s, listening: false }));
    rec.onend = () => setUI((s) => ({ ...s, listening: false }));
    rec.start();
    recognitionRef.current = rec;
    setUI((s) => ({ ...s, listening: true }));
  };

  return { ui, handleChange, toggleMic };
}

// TranscriptInput is the answer area for subjective questions. The prompt is
// rendered prominently above the textarea. The caller owns the value and the
// autosave side-effect; debouncing and mic state live inside the hook.
export function TranscriptInput({ prompt, value, onChange, onSave }: TranscriptInputProps) {
  const { ui, handleChange, toggleMic } = useTranscriptInput(value, onChange, onSave);
  const remaining = MAX_CHARS - value.length;
  const wordCount = value.trim() ? value.trim().split(/\s+/).length : 0;

  return (
    <div className="flex flex-col gap-5">
      {/* Question prompt — styled as a callout so it reads as a question, not a label */}
      <div className="rounded-[--radius-md] border border-border bg-muted/40 p-4">
        <p className="text-base leading-relaxed">{prompt}</p>
      </div>

      {/* Answer textarea */}
      <div className="relative">
        <textarea
          aria-label="Your answer"
          className="min-h-[320px] w-full resize-y rounded-[--radius-md] border border-border bg-background px-4 py-3 text-sm leading-relaxed placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          placeholder="Write your answer here…"
          value={value}
          onChange={(e) => handleChange(e.target.value)}
        />

        {/* Footer indicators */}
        <div className="absolute bottom-3 right-3 flex items-center gap-3 text-xs text-muted-foreground">
          {ui.saved && (
            <span className="flex items-center gap-1 text-ai">
              <CheckCircle2 className="h-3 w-3" aria-hidden />
              Saved
            </span>
          )}
          <span>{wordCount} word{wordCount !== 1 ? "s" : ""}</span>
          <span className={remaining < 500 ? "text-destructive" : ""}>
            {remaining.toLocaleString()} left
          </span>
        </div>
      </div>

      {/* Mic button — only mounted after hydration confirms browser support */}
      {ui.hasSpeech && (
        <div className="flex items-center gap-3">
          <Button
            type="button"
            variant={ui.listening ? "destructive" : "outline"}
            size="sm"
            aria-label={ui.listening ? "Stop recording" : "Start voice input"}
            onClick={toggleMic}
            className={cn("w-fit gap-2", ui.listening && "animate-pulse")}
          >
            {ui.listening ? (
              <>
                <MicOff className="h-4 w-4" aria-hidden />
                Stop recording
              </>
            ) : (
              <>
                <Mic className="h-4 w-4" aria-hidden />
                Speak your answer
              </>
            )}
          </Button>
          {ui.listening && (
            <span className="flex items-center gap-1.5 text-xs text-destructive">
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-destructive opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-destructive" />
              </span>
              Recording…
            </span>
          )}
        </div>
      )}
    </div>
  );
}
