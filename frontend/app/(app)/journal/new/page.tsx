import type { Metadata } from "next";

import ROUTES from "@/lib/routes";
import { getJournalCategories } from "@/lib/server/journal";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { JournalEntryForm } from "@/components/journal/journal-entry-form";
import { PageHeader } from "@/components/shared/page-header";

export const metadata: Metadata = { title: "Add Learning" };

export default async function NewJournalEntryPage() {
  const categories = await getJournalCategories();

  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ label: "Learning Journal", href: ROUTES.JOURNAL }, { label: "Add Learning" }]} />
      <PageHeader title="Add Learning" description="Log what you learned today under a category." />

      <JournalEntryForm categories={categories} />
    </main>
  );
}
