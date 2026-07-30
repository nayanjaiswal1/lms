"use client";

import { Breadcrumb } from "@/components/shared/breadcrumb";
import { useBatchName } from "@/app/(app)/batches/[id]/batch-name-context";
import ROUTES from "@/lib/routes";

interface Props {
  batchId: string;
  testTitle: string;
}

// BatchBreadcrumb (rendered by the shared layout) skips this route since it
// doesn't have the test's title — this renders the full trail instead, using
// the batch name from context so no duplicate batch fetch is needed.
export function TestDetailBreadcrumb({ batchId, testTitle }: Props) {
  const batchName = useBatchName();

  return (
    <Breadcrumb
      items={[
        { label: "Batches", href: ROUTES.BATCHES },
        { label: batchName, href: ROUTES.batch(batchId) },
        { label: "Tests", href: ROUTES.batchTests(batchId) },
        { label: testTitle },
      ]}
    />
  );
}
