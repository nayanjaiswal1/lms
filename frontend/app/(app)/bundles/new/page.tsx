import { notFound } from "next/navigation";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { BundleEditor } from "@/components/bundles/bundle-editor";
import { getPickableCourses } from "@/lib/server/bundles";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";
import { PageHeader } from "@/components/shared/page-header";

export const metadata = { title: "New Bundle" };

export default async function NewBundlePage() {
  const permissions = await getMyPermissions();
  if (!permissions.includes(PERMISSIONS.COURSES.CREATE)) notFound();
  const courses = await getPickableCourses();

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Courses", href: ROUTES.COURSES }, { label: "New bundle" }]} />
      <PageHeader title="Create a Course Bundle">
        <p className="text-sm text-muted-foreground">
          Club existing courses into one ordered path. Students can enroll in all of them at once.
        </p>
      </PageHeader>
      <BundleEditor bundle={null} courses={courses} />
    </main>
  );
}
