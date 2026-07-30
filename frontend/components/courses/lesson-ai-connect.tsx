"use client";

import { useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { Sparkles, Copy, ExternalLink } from "lucide-react";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";

interface LessonAIConnectProps {
  moduleId: string;
  moduleTitle: string;
  lessonUrl: string;
  hasConnection: boolean;
}

// A shortcut into the AI Connector (docs/ai-connector.md) from the lesson
// page itself — no chat happens here and no LLM call is made by MindForge.
// This only shortens the path to the student's own already-connected (or
// not-yet-connected) Claude/ChatGPT: copy a context blob for this exact
// lesson, then continue the conversation in their own client, which already
// has full tool access (get_lesson, save_my_lesson_note, log_understanding,
// etc.) via the existing OAuth-connected MCP session.
export function LessonAIConnect({ moduleId, moduleTitle, lessonUrl, hasConnection }: LessonAIConnectProps) {
  const [question, setQuestion] = useState("");

  async function copyForAI() {
    const blob = [
      `I'm looking at the MindForge lesson "${moduleTitle}" (${lessonUrl}, module id: ${moduleId}).`,
      question.trim() ? `My question: ${question.trim()}` : "Can you help me understand this lesson?",
    ].join("\n\n");
    await navigator.clipboard.writeText(blob);
    toast.success("Copied — paste it into your connected AI.");
  }

  return (
    <Sheet>
      <SheetTrigger asChild>
        <Button size="sm" variant="outline">
          <Sparkles aria-hidden className="mr-2 h-4 w-4 text-ai" />
          Ask your AI
        </Button>
      </SheetTrigger>
      <SheetContent className="modal-responsive flex flex-col gap-4">
        <SheetHeader>
          <SheetTitle>Ask your AI</SheetTitle>
        </SheetHeader>

        {!hasConnection ? (
          <div className="ai-surface flex flex-col gap-3 p-4">
            <p className="text-sm text-foreground">
              Connect your own Claude or ChatGPT to MindForge once, and it can read this lesson,
              save notes, and log what you understood — right from your own chat.
            </p>
            <Button asChild className="w-fit" size="sm">
              <Link href={ROUTES.SETTINGS_INTEGRATIONS}>Connect your AI</Link>
            </Button>
          </div>
        ) : (
          <>
            <p className="text-sm text-muted-foreground">
              Your AI is already connected. Type your question, copy it, then paste it into your
              Claude or ChatGPT chat — it already has full access to this lesson.
            </p>
            <Textarea
              className="min-h-32"
              placeholder="What do you want to ask about this lesson?"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
            />
            <div className="flex flex-wrap gap-2">
              <Button size="sm" onClick={copyForAI}>
                <Copy aria-hidden className="mr-2 h-3.5 w-3.5" />
                Copy for your AI
              </Button>
              <Button asChild size="sm" variant="outline">
                <a href="https://claude.ai/new" rel="noopener noreferrer" target="_blank">
                  Open Claude <ExternalLink aria-hidden className="ml-2 h-3.5 w-3.5" />
                </a>
              </Button>
              <Button asChild size="sm" variant="outline">
                <a href="https://chatgpt.com" rel="noopener noreferrer" target="_blank">
                  Open ChatGPT <ExternalLink aria-hidden className="ml-2 h-3.5 w-3.5" />
                </a>
              </Button>
            </div>
          </>
        )}

        <Link
          className="text-xs text-muted-foreground underline-offset-2 hover:underline"
          href={ROUTES.SETTINGS_INTEGRATIONS_ACTIVITY}
        >
          See what your AI has done →
        </Link>
      </SheetContent>
    </Sheet>
  );
}
