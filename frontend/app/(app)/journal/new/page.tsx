import type { Metadata } from "next";

import ROUTES from "@/lib/routes";
import { getJournalCategories } from "@/lib/server/journal";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { JournalEntryForm } from "@/components/journal/journal-entry-form";

export const metadata: Metadata = { title: "Add Learning" };

export default async function NewJournalEntryPage() {
  const categories = await getJournalCategories();

  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ label: "Learning Journal", href: ROUTES.JOURNAL }, { label: "Add Learning" }]} />
      <div className="page-header">
        <div>
          <h1 className="section-title">Add Learning</h1>
          <p className="text-sm text-muted-foreground">Log what you learned today under a category.</p>
        </div>
      </div>

      <JournalEntryForm categories={categories} />
    </main>
  );
}
