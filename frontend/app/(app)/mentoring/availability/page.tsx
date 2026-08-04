import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getMyAvailability } from "@/lib/server/sessions";
import { WeeklyAvailabilityEditor } from "@/components/sessions/weekly-availability-editor";
import { AvailabilityExceptions } from "@/components/sessions/availability-exceptions";

export const metadata = { title: "My Availability" };

export default async function MentorAvailabilityPage() {
  await requireAccess(FEATURES.SESSION_BOOKING);
  const { rules, exceptions } = await getMyAvailability();

  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <h1 className="page-title">My Availability</h1>
        <p className="text-muted-foreground">
          Students book into these windows — set your weekly hours, then add one-off overrides for
          holidays or extra open days.
        </p>
      </div>

      <section className="mb-10 flex flex-col gap-4">
        <h2 className="section-title">Weekly hours</h2>
        <WeeklyAvailabilityEditor rules={rules} />
      </section>

      <section>
        <AvailabilityExceptions exceptions={exceptions} />
      </section>
    </main>
  );
}
