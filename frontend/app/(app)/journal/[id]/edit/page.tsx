import type { Metadata } from "next";

import ROUTES from "@/lib/routes";
import { getJournalCategories, getJournalEntry } from "@/lib/server/journal";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { JournalEntryForm } from "@/components/journal/journal-entry-form";

export const metadata: Metadata = { title: "Edit Entry" };

interface EditJournalEntryPageProps {
  params: Promise<{ id: string }>;
}

export default async function EditJournalEntryPage({ params }: EditJournalEntryPageProps) {
  const { id } = await params;
  const [entry, categories] = await Promise.all([getJournalEntry(id), getJournalCategories()]);

  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ label: "Learning Journal", href: ROUTES.JOURNAL }, { label: "Edit" }]} />
      <div className="page-header">
        <div>
          <h1 className="section-title">Edit Entry</h1>
        </div>
      </div>

      <JournalEntryForm categories={categories} entry={entry} />
    </main>
  );
}
