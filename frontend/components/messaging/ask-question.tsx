"use client";

import { useRef, useState, useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { askQuestionAction, getSimilarFAQsAction } from "@/lib/messaging/actions";
import type { SimilarFAQ } from "@/lib/server/messaging";

interface AskQuestionProps {
  courseId: string;
  batchId: string;
}

const DEBOUNCE_MS = 400;
const MIN_QUERY_LENGTH = 8;

export function AskQuestion({ courseId, batchId }: AskQuestionProps) {
  const [body, setBody] = useState("");
  const [similar, setSimilar] = useState<SimilarFAQ[]>([]);
  const [isSubmitting, startSubmitTransition] = useTransition();
  const [isSearching, startSearchTransition] = useTransition();
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  function handleChange(value: string) {
    setBody(value);

    if (debounceRef.current) clearTimeout(debounceRef.current);

    const query = value.trim();
    if (query.length < MIN_QUERY_LENGTH) {
      setSimilar([]);
      return;
    }

    debounceRef.current = setTimeout(() => {
      startSearchTransition(async () => {
        const result = await getSimilarFAQsAction(courseId, query);
        setSimilar(result.ok ? (result.data?.faqs ?? []) : []);
      });
    }, DEBOUNCE_MS);
  }

  function handleSubmit() {
    const trimmed = body.trim();
    if (!trimmed) return;

    startSubmitTransition(async () => {
      const result = await askQuestionAction(batchId, trimmed);
      if (result.ok) {
        toast.success("Question posted", { description: "Your mentor will be notified." });
        setBody("");
        setSimilar([]);
      } else {
        toast.error(result.error ?? "Failed to post your question.");
      }
    });
  }

  return (
    <section aria-label="Ask a question" className="card-base flex flex-col gap-4 p-6">
      <h2 className="section-title">Ask a question</h2>

      <Textarea
        aria-label="Your question"
        className="min-h-28 resize-none text-sm"
        disabled={isSubmitting}
        placeholder="What would you like to ask about this course?"
        value={body}
        onChange={(e) => handleChange(e.target.value)}
      />

      {isSearching && (
        <p className="text-sm text-muted-foreground">Checking for similar questions…</p>
      )}

      {!isSearching && similar.length > 0 && (
        <div className="ai-surface flex flex-col gap-3 p-4">
          <div className="flex items-center gap-2">
            <span className="ai-badge">Suggested</span>
            <p className="text-sm font-medium">Similar questions already answered</p>
          </div>
          <ul className="flex flex-col gap-3">
            {similar.map((faq) => (
              <li key={faq.id}>
                <p className="text-sm font-medium">{faq.question}</p>
                <p className="mt-1 text-sm text-muted-foreground">{faq.answer}</p>
              </li>
            ))}
          </ul>
        </div>
      )}

      <Button
        className="w-fit"
        disabled={isSubmitting || body.trim().length === 0}
        size="sm"
        onClick={handleSubmit}
      >
        {isSubmitting ? "Posting…" : "Post question"}
      </Button>
    </section>
  );
}
