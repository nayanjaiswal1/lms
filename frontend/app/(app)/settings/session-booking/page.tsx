import { notFound } from "next/navigation";
import { requireOrgFeature } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { getBookingConfig, listPacks } from "@/lib/server/sessions";
import { BookingPolicyForm } from "@/components/sessions/booking-policy-form";
import { CreditPackManager } from "@/components/sessions/credit-pack-manager";
import { GrantCreditsDialog } from "@/components/sessions/grant-credits-dialog";

export const metadata = { title: "Session Booking — MindForge" };

export default async function SessionBookingSettingsPage() {
  await requireOrgFeature(FEATURES.SESSION_BOOKING);
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.MENTORING.MANAGE_SESSION_BOOKING)) {
    notFound();
  }

  const [{ config }, packs] = await Promise.all([getBookingConfig(), listPacks(true)]);

  return (
    <div className="flex flex-col gap-8">
      <div className="flex flex-col gap-2">
        <h2 className="text-2xl font-semibold">Session booking</h2>
        <p className="text-muted-foreground">
          Set the org-wide booking policy and manage the credit packs students can buy.
        </p>
      </div>

      <section className="card-base flex flex-col gap-4 p-6">
        <h3 className="section-title">Policy</h3>
        <BookingPolicyForm config={config} />
      </section>

      <section className="card-base flex flex-col gap-3 p-6">
        <div>
          <h3 className="section-title">Grant or revoke credits</h3>
          <p className="text-sm text-muted-foreground">
            Adjust a specific student&apos;s session credit balance directly — for support cases or manual
            corrections.
          </p>
        </div>
        <div>
          <GrantCreditsDialog />
        </div>
      </section>

      <section className="flex flex-col gap-4">
        <h3 className="section-title">Credit packs</h3>
        <CreditPackManager packs={packs} />
      </section>
    </div>
  );
}
