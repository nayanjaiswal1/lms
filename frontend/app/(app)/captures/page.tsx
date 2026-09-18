import type { Metadata } from "next";

import { getCaptures } from "@/lib/server/captures";
import { CaptureUploadForm } from "@/components/captures/capture-upload-form";
import { CaptureList } from "@/components/captures/capture-list";
import { CapturesPoller } from "@/components/captures/captures-poller";

export const metadata: Metadata = { title: "Captures" };

export default async function CapturesPage() {
  const captures = await getCaptures();
  const hasInFlight = captures.some((c) => c.status === "pending" || c.status === "processing");

  return (
    <main className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Captures</h1>
          <p className="text-sm text-muted-foreground">
            Screenshots, PDFs, and links you don&apos;t want to lose — sorted into your journal or
            flashcards automatically.
          </p>
        </div>
      </div>

      <CaptureUploadForm />
      <div className="mt-6">
        <CaptureList captures={captures} />
      </div>

      <CapturesPoller hasInFlight={hasInFlight} />
    </main>
  );
}
