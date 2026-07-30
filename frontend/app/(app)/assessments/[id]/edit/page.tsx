import { notFound } from "next/navigation";

import { getAssessment, getQuestions, getQuestionTags } from "@/lib/assessments/server";
import { QuestionsPanel } from "@/app/(app)/assessments/[id]/edit/questions-panel";

interface PageProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ test_q?: string; bank_q?: string; type?: string; difficulty?: string; tag?: string }>;
}

// Every filter/search param is forwarded straight to the API — the backend
// (not this page or the client component) owns filtering, search, and
// ordering for both the attached-questions and question-bank queries.
function sharedFilterParams(sp: Awaited<PageProps["searchParams"]>): string {
  const parts: string[] = [];
  if (sp.type && sp.type !== "all") parts.push(`type=${encodeURIComponent(sp.type)}`);
  if (sp.difficulty && sp.difficulty !== "all") parts.push(`difficulty=${encodeURIComponent(sp.difficulty)}`);
  if (sp.tag && sp.tag !== "all") parts.push(`tags=${encodeURIComponent(sp.tag)}`);
  return parts.join("&");
}

export default async function AssessmentQuestionsPage({ params, searchParams }: PageProps) {
  const { id } = await params;
  const sp = await searchParams;
  const shared = sharedFilterParams(sp);

  const testSearch = sp.test_q?.trim() ? `&search=${encodeURIComponent(sp.test_q.trim())}` : "";
  const bankSearch = sp.bank_q?.trim() ? `&search=${encodeURIComponent(sp.bank_q.trim())}` : "";

  let detail: Awaited<ReturnType<typeof getAssessment>>;
  try {
    detail = await getAssessment(id, `?${shared}${testSearch}`);
  } catch {
    notFound();
  }

  const [bank, tags] = await Promise.all([
    getQuestions(`?limit=100&exclude_assessment_id=${id}&${shared}${bankSearch}`),
    getQuestionTags(),
  ]);

  return (
    <QuestionsPanel assessment={detail.assessment} attached={detail.questions} bank={bank.questions} tags={tags} />
  );
}
