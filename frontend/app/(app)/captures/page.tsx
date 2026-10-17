import type { Metadata } from "next";

import { getCaptures } from "@/lib/server/captures";
import { CaptureUploadForm } from "@/components/captures/capture-upload-form";
import { CaptureList } from "@/components/captures/capture-list";
import { RefreshPoller } from "@/components/shared/refresh-poller";
import { PageHeader } from "@/components/shared/page-header";

export const metadata: Metadata = { title: "Captures" };

export default async function CapturesPage() {
  const captures = await getCaptures();
  const hasInFlight = captures.some((c) => c.status === "pending" || c.status === "processing");

  return (
    <main className="page-container">
      <PageHeader
        title="Captures"
        description={<p className="page-description">
            Screenshots, PDFs, and links you don&apos;t want to lose — sorted into your journal or
            flashcards automatically.
          </p>} />

      <CaptureUploadForm />
      <div className="mt-6">
        <CaptureList captures={captures} />
      </div>

      <RefreshPoller active={hasInFlight} />
    </main>
  );
}
