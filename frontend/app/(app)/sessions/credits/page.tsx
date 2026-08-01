import type { Metadata } from "next";
import { Coins } from "lucide-react";
import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getBookingConfig, getCredits, listPacks, type LedgerReason } from "@/lib/server/sessions";
import { CreditPackCard } from "@/components/sessions/credit-pack-card";
import { cn } from "@/lib/utils";

export const metadata: Metadata = {
  title: "Session Credits",
  description: "Buy session credits and review your credit history.",
};

// Human labels for the ledger's fixed reason enum — mirrors LedgerReason in
// lib/server/sessions.ts one-to-one, so a new backend reason fails typecheck
// here instead of silently rendering as a raw snake_case string.
const REASON_LABEL: Record<LedgerReason, string> = {
  purchase: "Purchased",
  admin_grant: "Granted by admin",
  admin_revoke: "Revoked",
  booking: "Session booked",
  cancellation_refund: "Cancellation refund",
};

export default async function SessionCreditsPage() {
  await requireAccess(FEATURES.SESSION_BOOKING);

  const [{ balance, entries }, packs, { config }] = await Promise.all([
    getCredits(),
    listPacks(),
    getBookingConfig(),
  ]);

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Session Credits</h1>
          <p className="text-muted-foreground">
            {config.require_credits
              ? "Your organization requires a credit to book a mentor session."
              : "Buy credits to book mentor sessions faster, or track your history below."}
          </p>
        </div>
      </header>

      <section className="card-raised mb-8 flex items-center gap-4">
        <div className="flex-center h-14 w-14 rounded-full bg-primary/10">
          <Coins aria-hidden className="h-7 w-7 text-primary" />
        </div>
        <div>
          <p className="text-4xl font-bold tracking-tight">{balance}</p>
          <p className="text-sm text-muted-foreground">
            session credit{balance === 1 ? "" : "s"} available
          </p>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="section-title mb-4">Buy more</h2>
        {packs.length === 0 ? (
          <div className="empty-state">
            <p className="text-sm">No credit packs are available right now.</p>
          </div>
        ) : (
          <div className="card-grid">
            {packs.map((pack) => (
              <CreditPackCard key={pack.id} pack={pack} />
            ))}
          </div>
        )}
      </section>

      <section>
        <h2 className="section-title mb-4">History</h2>
        {entries.length === 0 ? (
          <div className="empty-state">
            <p className="text-sm">No credit activity yet.</p>
          </div>
        ) : (
          <div className="table-responsive">
            <table className="w-full text-sm">
              <thead>
                <tr className="whitespace-nowrap border-b border-border text-left text-muted-foreground">
                  <th className="pb-2 pr-6 font-medium">Date</th>
                  <th className="pb-2 pr-6 font-medium">Reason</th>
                  <th className="pb-2 pr-6 font-medium">Change</th>
                  <th className="pb-2 font-medium">Note</th>
                </tr>
              </thead>
              <tbody>
                {entries.map((entry) => (
                  <tr className="whitespace-nowrap border-b border-border last:border-0" key={entry.id}>
                    <td className="py-3 pr-6 text-muted-foreground">
                      {new Date(entry.created_at).toLocaleDateString(undefined, {
                        year: "numeric",
                        month: "short",
                        day: "numeric",
                      })}
                    </td>
                    <td className="py-3 pr-6">{REASON_LABEL[entry.reason]}</td>
                    <td className={cn("py-3 pr-6 font-medium", entry.delta >= 0 ? "text-success" : "text-destructive")}>
                      {entry.delta >= 0 ? `+${entry.delta}` : entry.delta}
                    </td>
                    <td className="min-w-0 max-w-64 whitespace-normal py-3 text-muted-foreground">
                      {entry.note ?? "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}
