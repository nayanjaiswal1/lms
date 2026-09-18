import type { Metadata } from "next";

import { getAdminWhatsNewEntries } from "@/lib/server/whats-new";
import { EntryFormDialog } from "./entry-form-dialog";
import { EntryRow } from "./entry-row";

export const metadata: Metadata = { title: "What's new" };

export default async function PlatformWhatsNewPage() {
  const entries = await getAdminWhatsNewEntries();

  return (
    <div className="page-container">
      <header className="page-header">
        <div>
          <h1 className="page-title">What&apos;s new</h1>
          <p className="mt-1 text-muted-foreground">
            Entries shown in the sidebar&apos;s sparkle-icon panel. Published entries go live immediately — no redeploy.
          </p>
        </div>
        <EntryFormDialog />
      </header>

      {entries.length === 0 ? (
        <p className="empty-state mt-6">No entries yet — add one to populate the sidebar panel.</p>
      ) : (
        <div className="stack-md mt-6">
          {entries.map((entry) => (
            <EntryRow entry={entry} key={entry.id} />
          ))}
        </div>
      )}
    </div>
  );
}
