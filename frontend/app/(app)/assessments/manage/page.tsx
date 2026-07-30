import type { Metadata } from "next";
import Link from "next/link";
import { ClipboardCheck, Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { getAssessments, getOrgAnalytics, getBatches } from "@/lib/assessments/server";
import { AssessmentList } from "@/app/(app)/assessments/manage/assessment-list";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Assessments",
  description: "Author, publish, and assign assessments.",
};

interface InstructorAssessmentsPageProps {
  searchParams: Promise<{ search?: string }>;
}

export default async function InstructorAssessmentsPage({ searchParams }: InstructorAssessmentsPageProps) {
  const { search } = await searchParams;
  const query = search?.trim() ?? "";
  const qs = query ? `&search=${encodeURIComponent(query)}` : "";

  const [assessments, org, batches] = await Promise.all([
    getAssessments(`?limit=200${qs}`),
    getOrgAnalytics(),
    getBatches(),
  ]);

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Assessments</h1>
          <p className="text-muted-foreground">
            {org.total_assessments} assessments · {org.total_attempts} attempts · {Math.round(org.avg_pass_rate)}% avg pass rate
          </p>
        </div>
        <Button asChild>
          <Link href={ROUTES.MANAGE_ASSESSMENT_NEW}>
            <Plus /> New assessment
          </Link>
        </Button>
      </header>

      {assessments.length === 0 && !query ? (
        <div className="empty-state mt-10">
          <ClipboardCheck aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No assessments yet</p>
          <p className="text-sm text-muted-foreground">Create one, add questions from your bank, then assign it.</p>
        </div>
      ) : (
        <div className="mt-8">
          <AssessmentList assessments={assessments} batches={batches} />
        </div>
      )}
    </main>
  );
}
