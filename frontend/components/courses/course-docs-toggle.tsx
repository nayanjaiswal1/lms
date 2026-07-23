"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { toast } from "sonner";
// Course management reaches into the wiki feature deliberately — enabling
// "Course Docs" creates a course-linked wiki space, per docs/wiki.md's
// "Course-linked spaces — auto-created when instructor enables wiki for a
// course" — see the matching boundaries/dependencies allow-list entry in
// eslint.config.mjs.
import { createSpaceAction } from "@/lib/wiki/actions";
import ROUTES from "@/lib/routes";

interface CourseDocsToggleProps {
  courseId: string;
  courseTitle: string;
  existingSpaceSlug: string | null;
}

export function CourseDocsToggle({ courseId, courseTitle, existingSpaceSlug }: CourseDocsToggleProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  if (existingSpaceSlug) {
    return (
      <Link className="text-sm text-primary hover:underline" href={ROUTES.wikiSpace(existingSpaceSlug)}>
        Course Docs
      </Link>
    );
  }

  function handleEnable() {
    startTransition(async () => {
      const result = await createSpaceAction({ name: `${courseTitle} Docs`, course_id: courseId, visibility: "members" });
      if (!result.ok || !result.data) {
        toast.error(result.error ?? "Couldn't enable Course Docs.");
        return;
      }
      toast.success("Course Docs enabled");
      router.push(ROUTES.wikiSpace(result.data.slug));
    });
  }

  return (
    <button className="text-sm text-primary hover:underline disabled:opacity-60" disabled={pending} type="button" onClick={handleEnable}>
      {pending ? "Enabling…" : "Enable Course Docs"}
    </button>
  );
}
