"use client";

import { usePathname } from "next/navigation";

import { Breadcrumb, type BreadcrumbItem } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

interface Props {
  assessmentId: string;
  title: string;
}

const SEGMENT_LABELS: Record<string, string> = {
  batches: "Assign",
  settings: "Test configuration",
};

// Renders "Assessments / {title} / {tab}" above the header for the tab
// pages this layout owns (questions/batches/settings). results/review are
// siblings of edit/, not children — they render their own breadcrumb outside
// this layout entirely.
export function AssessmentBreadcrumb({ assessmentId, title }: Props) {
  const pathname = usePathname();
  const base = ROUTES.assessmentEdit(assessmentId);
  const rest = pathname.startsWith(base) ? pathname.slice(base.length).replace(/^\/+/, "") : "";
  const segment = rest.split("/")[0] ?? "";

  const items: BreadcrumbItem[] = [{ label: "Assessments", href: ROUTES.ASSESSMENTS }];

  if (!segment) {
    items.push({ label: title });
  } else {
    items.push({ label: title, href: base });
    items.push({ label: SEGMENT_LABELS[segment] ?? segment });
  }

  return <Breadcrumb items={items} />;
}
