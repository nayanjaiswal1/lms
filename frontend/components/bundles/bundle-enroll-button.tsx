"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { enrollInBundleAction } from "@/lib/bundles/actions";

interface BundleEnrollButtonProps {
  bundleID: string;
  slug: string;
  paidCourseTitles: Record<string, string>;
}

// Enrolls in every free course of the bundle at once. Paid courses can't be
// granted here, so the toast names them for the student to buy one by one.
export function BundleEnrollButton({ bundleID, slug, paidCourseTitles }: BundleEnrollButtonProps) {
  const [pending, startTransition] = useTransition();

  function handleClick() {
    startTransition(async () => {
      const result = await enrollInBundleAction(bundleID, slug);
      if (!result.ok || !result.data) {
        toast.error(result.error ?? "Could not enroll. Please try again.");
        return;
      }
      const { enrolled_course_ids: enrolled, requires_purchase_course_ids: paid } = result.data;
      if (enrolled.length > 0) {
        toast.success(`Enrolled in ${enrolled.length} course${enrolled.length === 1 ? "" : "s"}.`);
      }
      if (paid.length > 0) {
        const titles = paid.map((id) => paidCourseTitles[id] ?? "a course").join(", ");
        toast.info(`Purchase needed for: ${titles}. Open each course to buy it.`);
      }
      if (enrolled.length === 0 && paid.length === 0) {
        toast.info("You're already enrolled in every course here.");
      }
    });
  }

  return (
    <Button className="touch-target" disabled={pending} onClick={handleClick}>
      {pending ? "Enrolling…" : "Enroll in all"}
    </Button>
  );
}
