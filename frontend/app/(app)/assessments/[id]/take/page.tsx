import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { TestRunner } from "@/components/assessments/test-runner";
import { startAttempt } from "@/lib/server/assessments";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Take Assessment",
  robots: { index: false, follow: false },
};

interface PageProps {
  params: Promise<{ id: string }>;
}

// Server component: starts (or resumes) the attempt server-side so the question
// payload — already stripped of answer keys — never round-trips through client
// state before render. Finished attempts redirect straight to the result page.
export default async function TakeAssessmentPage({ params }: PageProps) {
  const { id } = await params;

  let payload: Awaited<ReturnType<typeof startAttempt>>;
  try {
    payload = await startAttempt(id);
  } catch {
    redirect(ROUTES.ASSESSMENTS);
  }

  if (payload.attempt.status === "submitted" || payload.attempt.status === "evaluated") {
    redirect(ROUTES.assessmentResult(payload.attempt.id));
  }

  return <TestRunner payload={payload} />;
}
