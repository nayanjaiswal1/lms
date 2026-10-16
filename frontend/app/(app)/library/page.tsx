import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { LibraryBrowser } from "@/components/library/library-browser";
import { getLibraryItems } from "@/lib/library/server";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { PageHeader } from "@/components/shared/page-header";

export const metadata: Metadata = { title: "Library" };

// Standalone browse/preview/try page for the course library (labs, quizzes,
// notes) — see docs/courses.md "Course library ('Add from library')". Same
// instructor gate the course editor uses: placing content is an authoring
// action.
export default async function LibraryPage() {
  const [myPerms, initialPage] = await Promise.all([getMyPermissions(), getLibraryItems()]);
  if (!myPerms.includes(PERMISSIONS.COURSES.EDIT)) {
    notFound();
  }

  return (
    <main className="page-container">
      <PageHeader title="Library" description="Browse published labs, quizzes, and notes lessons — try a lab, or add one straight into a course." />
      <LibraryBrowser initialPage={initialPage} />
    </main>
  );
}
