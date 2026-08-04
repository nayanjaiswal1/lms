import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { getCurrentUser } from "@/lib/server/auth";
import { apiGet } from "@/lib/server/api";
import { safeNextPath } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import { AcceptLegalForm } from "@/app/legal/accept/accept-legal-form";

export const metadata: Metadata = {
  title: "Review our updated policies",
};

interface LegalAcceptPageProps {
  searchParams: Promise<{ next?: string }>;
}

export default async function LegalAcceptPage({ searchParams }: LegalAcceptPageProps) {
  const user = await getCurrentUser();
  if (!user) redirect(ROUTES.LOGIN);

  const { next } = await searchParams;
  const status = await apiGet<{ needs_acceptance: string[] }>("/api/legal/status");
  const needsTerms = status.needs_acceptance.includes("terms");
  const needsPrivacy = status.needs_acceptance.includes("privacy");

  if (!needsTerms && !needsPrivacy) {
    redirect(safeNextPath(next) ?? ROUTES.DASHBOARD);
  }

  return (
    // eslint-disable-next-line no-restricted-syntax -- standalone public page outside the (app) shell, no .app-content ancestor to supply vertical padding
    <main className="page-container-sm flex min-h-dvh flex-col items-center justify-center py-12">
      <div className="w-full max-w-md space-y-6">
        <div className="space-y-2 text-center">
          <h1 className="page-title">We&apos;ve updated our policies</h1>
          <p className="text-sm text-muted-foreground">
            Please review and accept before continuing to MindForge.
          </p>
        </div>
        <AcceptLegalForm needsPrivacy={needsPrivacy} needsTerms={needsTerms} next={next} />
      </div>
    </main>
  );
}
