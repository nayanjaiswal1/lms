import type { Metadata } from "next";
import Link from "next/link";
import { AlertTriangle, ExternalLink } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { getAssessment, getReviewQueue } from "@/lib/assessments/server";
import ROUTES from "@/lib/routes";
import type { ReviewQueueItem } from "@/lib/assessments/types";

export const metadata: Metadata = { title: "Flagged Attempts — Review Queue" };

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function ReviewQueuePage({ params }: PageProps) {
  const { id } = await params;
  // The queue itself is org-wide (not filtered by id), but this route is
  // reached from within one assessment's edit flow — id is only used here to
  // label the breadcrumb with that assessment's title, reusing the same
  // getAssessment() call the surrounding edit/layout.tsx already makes (Next
  // dedupes identical fetches within one render pass, so this isn't a second
  // network round trip).
  const [data, detail] = await Promise.all([getReviewQueue(), getAssessment(id)]);
  const items = data.items;

  return (
    <main className="page-container">
      <Breadcrumb
        items={[
          { label: "Assessments", href: ROUTES.ASSESSMENTS },
          { label: detail.assessment.title, href: ROUTES.assessmentEdit(id) },
          { label: "Review Queue" },
        ]}
      />
      <div className="page-header">
        <div>
          <h1 className="section-title">Review Queue</h1>
          <p className="text-muted-foreground text-sm mt-1">
            Attempts flagged for potential injection or anomalous scores.
          </p>
        </div>
        <Badge variant="secondary">{items.length} flagged</Badge>
      </div>

      {items.length === 0 ? (
        <div className="empty-state">
          <AlertTriangle aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="text-muted-foreground">No flagged attempts. All clear.</p>
        </div>
      ) : (
        <div className="table-responsive mt-6">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="pb-3 pr-4 font-medium">Student</th>
                <th className="pb-3 pr-4 font-medium">Assessment</th>
                <th className="pb-3 pr-4 font-medium">Composite</th>
                <th className="pb-3 pr-4 font-medium">Injection score</th>
                <th className="pb-3 font-medium">Flagged at</th>
                <th className="pb-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {items.map((item) => (
                <ReviewRow key={item.attempt_id} item={item} />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </main>
  );
}

function ReviewRow({ item }: { item: ReviewQueueItem }) {
  const flaggedAt = new Date(item.created_at).toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });

  return (
    <tr>
      <td className="py-3 pr-4">
        <span className="font-medium">{item.user_name}</span>
      </td>
      <td className="py-3 pr-4 text-muted-foreground">{item.assessment_title}</td>
      <td className="py-3 pr-4 tabular-nums">
        {item.composite_score !== null ? Math.round(item.composite_score) : "—"}
      </td>
      <td className="py-3 pr-4">
        <Badge variant={item.injection_score >= 40 ? "destructive" : "secondary"}>
          {item.injection_score}
        </Badge>
      </td>
      <td className="py-3 pr-4 text-muted-foreground">{flaggedAt}</td>
      <td className="py-3">
        <Button asChild size="sm" variant="outline">
          <Link href={ROUTES.assessmentResult(item.attempt_id)}>
            <ExternalLink className="h-3.5 w-3.5" aria-hidden />
            Review
          </Link>
        </Button>
      </td>
    </tr>
  );
}
