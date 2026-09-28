import { notFound } from "next/navigation";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { BundleEditor } from "@/components/bundles/bundle-editor";
import { getPickableCourses } from "@/lib/server/bundles";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";

export const metadata = { title: "New Bundle" };

export default async function NewBundlePage() {
  const permissions = await getMyPermissions();
  if (!permissions.includes(PERMISSIONS.COURSES.CREATE)) notFound();
  const courses = await getPickableCourses();

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Courses", href: ROUTES.COURSES }, { label: "New bundle" }]} />
      <div className="page-header mb-6">
        <h1 className="section-title">Create a Course Bundle</h1>
        <p className="text-sm text-muted-foreground">
          Club existing courses into one ordered path. Students can enroll in all of them at once.
        </p>
      </div>
      <BundleEditor bundle={null} courses={courses} />
    </main>
  );
}
