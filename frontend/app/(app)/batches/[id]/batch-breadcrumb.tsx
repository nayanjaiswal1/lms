"use client";

import { usePathname } from "next/navigation";

import { Breadcrumb, type BreadcrumbItem } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

interface Props {
  batchId: string;
  batchName: string;
  testsLabel: string;
}

const SEGMENT_LABELS: Record<string, string> = {
  analytics: "Analytics",
  chat: "Chat",
  courses: "Courses",
  progress: "Progress",
};

// Renders the shared "Batches / {batch name} / …" trail for every route under
// this layout, derived from the URL — no extra fetch needed since batchName is
// already fetched once here. The one route this can't label (tests/[testId],
// which needs the test's own title) renders its own Breadcrumb from the page
// instead — see batch-name-context.tsx.
export function BatchBreadcrumb({ batchId, batchName, testsLabel }: Props) {
  const pathname = usePathname();
  const base = ROUTES.batch(batchId);
  const rest = pathname.startsWith(base) ? pathname.slice(base.length).replace(/^\/+/, "") : "";
  const segments = rest ? rest.split("/") : [];

  const isTestDetail = segments[0] === "tests" && segments.length === 2 && segments[1] !== "new";
  if (isTestDetail) return null; // page renders its own trail with the test title

  const items: BreadcrumbItem[] = [{ label: "Batches", href: ROUTES.BATCHES }];

  if (segments.length === 0) {
    items.push({ label: batchName });
    return <Breadcrumb items={items} />;
  }

  items.push({ label: batchName, href: base });

  if (segments[0] === "tests") {
    if (segments.length === 1) {
      items.push({ label: testsLabel });
    } else {
      items.push({ label: testsLabel, href: ROUTES.batchTests(batchId) });
      items.push({ label: "New" }); // only remaining case: segments[1] === "new"
    }
  } else {
    items.push({ label: SEGMENT_LABELS[segments[0]] ?? segments[0] });
  }

  return <Breadcrumb items={items} />;
}
