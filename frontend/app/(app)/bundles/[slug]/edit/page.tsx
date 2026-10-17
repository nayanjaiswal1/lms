import { notFound } from "next/navigation";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { BundleEditor } from "@/components/bundles/bundle-editor";
import { getManagedBundleBySlug, getPickableCourses } from "@/lib/server/bundles";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";
import { PageHeader } from "@/components/shared/page-header";

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
      <PageHeader title="Edit Bundle" />
      <BundleEditor bundle={bundle} courses={courses} />
    </main>
  );
}
