import { notFound, redirect } from "next/navigation";
import { getCourseTree, getFinalTestForEdit, getCertificateRule, getInstructorCourseBySlug } from "@/lib/server/courses";
import { CourseWizard } from "@/components/courses/course-wizard";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  const course = await getInstructorCourseBySlug(slug).catch(() => undefined);
  return { title: course ? `Edit "${course.title}"` : "Edit Course" };
}

export default async function CourseSettingsPage({ params }: Props) {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.COURSES.EDIT)) {
    notFound();
  }

  const { slug } = await params;
  const course = await getInstructorCourseBySlug(slug).catch(() => undefined);
  if (!course) notFound();

  const tree = await getCourseTree(course.id).catch(() => null);
  if (!tree) {
    notFound();
  }

  if (tree.status === "archived") {
    redirect(ROUTES.courseEdit(slug));
  }

  const [finalTest, certificateRule] = await Promise.all([
    getFinalTestForEdit(course.id),
    getCertificateRule(course.id),
  ]);

  return (
    <main className="page-container">
      <Breadcrumb
        items={[
          { label: "Teach", href: ROUTES.TEACH },
          { label: tree.title, href: ROUTES.courseEdit(slug) },
          { label: "Settings" },
        ]}
      />

      <div className="page-header mb-6">
        <div className="flex flex-col gap-1">
          <h1 className="section-title">Course settings</h1>
          <p className="text-sm text-muted-foreground">{tree.title}</p>
        </div>
      </div>
      <CourseWizard certificateRule={certificateRule} course={tree} finalTest={finalTest} />
    </main>
  );
}
