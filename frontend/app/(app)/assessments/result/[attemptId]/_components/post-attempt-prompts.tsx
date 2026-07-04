"use client";

import { useState } from "react";
import { ExperienceReportPrompt } from "@/components/assessments/experience-report-prompt";
import { FeedbackPrompt } from "@/components/feedback/feedback-prompt";

interface PostAttemptPromptsProps {
  attemptId: string;
  assessmentId: string;
  alreadyReportedExperience: boolean;
  alreadyRatedFeedback: boolean;
}

// Colocated with the result page (not under components/) because it crosses
// the assessments/feedback feature boundary: it shows the experience report
// ("did anything go wrong with this attempt") first, then the star-rating
// feedback prompt ("how would you rate this assessment") — never both
// dialogs at once.
export function PostAttemptPrompts({
  attemptId,
  assessmentId,
  alreadyReportedExperience,
  alreadyRatedFeedback,
}: PostAttemptPromptsProps) {
  const [experienceDone, setExperienceDone] = useState(alreadyReportedExperience);

  if (!experienceDone) {
    return (
      <ExperienceReportPrompt
        alreadyResponded={alreadyReportedExperience}
        attemptId={attemptId}
        onDone={() => setExperienceDone(true)}
      />
    );
  }

  return <FeedbackPrompt alreadyResponded={alreadyRatedFeedback} subjectId={assessmentId} subjectType="assessment" />;
}
