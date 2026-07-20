import type { Metadata } from "next";
import Link from "next/link";
import { Users } from "lucide-react";

import { getBatches } from "@/lib/assessments/server";
import { BatchesPanel } from "@/app/(app)/batches/batches-panel";
import { BatchAvatar } from "@/components/batches/batch-avatar";
import { getCurrentOrgType } from "@/lib/orgs/server";
import { resolveTerminology } from "@/lib/terminology";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Batches",
  description: "Group students into cohorts for assignment.",
};

export default async function BatchesPage() {
  const [batches, orgType] = await Promise.all([getBatches(), getCurrentOrgType()]);
  const t = resolveTerminology(orgType);

  return (
    <main className="page-container py-10">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">{t.classPlural}</h1>
          <p className="text-muted-foreground">Cohorts you can assign assessments to in one action.</p>
        </div>
        <BatchesPanel />
      </header>

      {batches.length === 0 ? (
        <div className="empty-state mt-10">
          <Users aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No {t.classPlural.toLowerCase()} yet</p>
          <p className="text-sm text-muted-foreground">Create a {t.class_.toLowerCase()}, then add {t.studentPlural.toLowerCase()} to it.</p>
        </div>
      ) : (
        <section className="card-grid mt-8">
          {batches.map((b) => (
            <Link
              className="card-interactive flex flex-col gap-2 p-6"
              href={ROUTES.batch(b.id)}
              key={b.id}
            >
              <div className="flex items-center gap-3">
                <BatchAvatar batchId={b.id} imageUrl={b.image_url} name={b.name} />
                <h3 className="text-base font-semibold">{b.name}</h3>
              </div>
              {b.description && <p className="line-clamp-2 text-sm text-muted-foreground">{b.description}</p>}
              <p className="mt-auto text-sm text-muted-foreground">{b.member_count} members</p>
            </Link>
          ))}
        </section>
      )}
    </main>
  );
}
