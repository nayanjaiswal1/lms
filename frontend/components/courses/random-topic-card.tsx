"use client";

import { useState } from "react";
import Link from "next/link";
import { Clock, Loader2, Shuffle, Star } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { getRandomTopicAction } from "@/lib/courses/actions";
import type { RandomTopic } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface RandomTopicCardProps {
  initialTopic: RandomTopic | null;
}

// "Surprise me" discovery card. initialTopic is server-rendered on first
// load; "Try another" re-rolls client-side via a server action, since a
// fresh random pick can't be served from a cached prop.
export function RandomTopicCard({ initialTopic }: RandomTopicCardProps) {
  const [topic, setTopic] = useState(initialTopic);
  const [pending, setPending] = useState(false);

  async function handleReroll() {
    setPending(true);
    const result = await getRandomTopicAction();
    setPending(false);
    if (result.error || !result.data) {
      toast.error(result.error ?? "No courses to suggest yet.");
      return;
    }
    setTopic(result.data);
  }

  if (!topic) {
    return (
      <div className="card-base flex items-center gap-3 p-4">
        <Shuffle aria-hidden className="h-5 w-5 shrink-0 text-muted-foreground" />
        <p className="text-sm text-muted-foreground">Nothing to suggest yet.</p>
      </div>
    );
  }

  const { course } = topic;

  return (
    <div className="card-base flex flex-col gap-3 p-4">
      <div aria-busy={pending} className="flex min-w-0 flex-col gap-1.5">
        <div className="flex items-center gap-1.5">
          <Shuffle aria-hidden className="h-4 w-4 text-primary" />
          <span className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            {topic.matched_interest ? "Picked for your interests" : "Random topic to learn"}
          </span>
        </div>

        <Link className="line-clamp-1 text-base font-semibold leading-snug hover:underline" href={ROUTES.course(course.slug)}>
          {course.title}
        </Link>

        <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
          <span className={`difficulty-${course.difficulty} rounded-full border px-2 py-0.5 font-medium capitalize`}>
            {course.difficulty}
          </span>
          {course.estimated_hours && (
            <span className="flex items-center gap-1">
              <Clock aria-hidden className="h-3.5 w-3.5" />
              {course.estimated_hours}h
            </span>
          )}
          {course.avg_rating !== null && (
            <span className="flex items-center gap-1">
              <Star aria-hidden className="h-3.5 w-3.5 fill-primary text-primary" />
              {course.avg_rating.toFixed(1)}
            </span>
          )}
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        <Button asChild className="h-7 px-3 text-xs" size="sm">
          <Link href={ROUTES.course(course.slug)}>
            {topic.already_enrolled ? "Continue" : "Start learning"}
          </Link>
        </Button>
        <Button aria-label="Try another random topic" className="h-7 px-3 text-xs" disabled={pending} size="sm" variant="outline" onClick={handleReroll}>
          {pending ? <Loader2 aria-hidden className="mr-1.5 h-3.5 w-3.5 animate-spin" /> : <Shuffle aria-hidden className="mr-1.5 h-3.5 w-3.5" />}
          Try another
        </Button>
      </div>
    </div>
  );
}
