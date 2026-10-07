import type { ReactNode } from "react";

import { LEGAL_PAGES_LAST_UPDATED } from "@/lib/legal-constants";

interface LegalPageProps {
  title: string;
  children: ReactNode;
}

/** Shared shell for the standalone public legal pages. */
export function LegalPage({ title, children }: LegalPageProps) {
  return (
    // eslint-disable-next-line no-restricted-syntax -- standalone public page outside the (app) shell, no .app-content ancestor to supply vertical padding
    <main className="page-container-sm py-12">
      <h1 className="page-title">{title}</h1>
      <p className="text-sm text-muted-foreground">Last updated: {LEGAL_PAGES_LAST_UPDATED}</p>
      <div className="prose-content mt-8">{children}</div>
    </main>
  );
}
