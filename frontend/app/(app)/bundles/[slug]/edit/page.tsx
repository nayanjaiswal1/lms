import { notFound } from "next/navigation";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { BundleEditor } from "@/components/bundles/bundle-editor";
import { getManagedBundleBySlug, getPickableCourses } from "@/lib/server/bundles";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Edit Bundle" };

interface Props {
  params: Promise<{ slug: string }>;
}

export default async function EditBundlePage({ params }: Props) {
  const { slug } = await params;
  const permissions = await getMyPermissions();
  if (!permissions.includes(PERMISSIONS.COURSES.CREATE)) notFound();

  const [bundle, courses] = await Promise.all([getManagedBundleBySlug(slug), getPickableCourses()]);
  if (!bundle) notFound();

  return (
    <main className="page-container">
      <Breadcrumb
        items={[
          { label: "Courses", href: ROUTES.COURSES },
          { label: bundle.title, href: ROUTES.bundle(bundle.slug) },
          { label: "Edit" },
        ]}
      />
      <div className="page-header mb-6">
        <h1 className="section-title">Edit Bundle</h1>
      </div>
      <BundleEditor bundle={bundle} courses={courses} />
    </main>
  );
}
