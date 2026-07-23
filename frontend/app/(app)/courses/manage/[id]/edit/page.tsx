import { notFound, redirect } from "next/navigation";
import Link from "next/link";
import { getCourseTree, getFinalTestForEdit } from "@/lib/server/courses";
import { CourseWizard } from "@/components/courses/course-wizard";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const tree = await getCourseTree(id).catch(() => null);
  return { title: tree ? `Edit "${tree.title}" — MindForge` : "Edit Course — MindForge" };
}

export default async function EditCoursePage({ params }: Props) {
  const { id } = await params;
  const tree = await getCourseTree(id).catch(() => null);

  if (!tree) {
    notFound();
  }

  if (tree.status === "archived") {
    redirect(ROUTES.manageCourse(id));
  }

  const finalTest = await getFinalTestForEdit(id);

  return (
    <main className="page-container py-8">
      <div className="page-header mb-6">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Edit course</h1>
          <p className="text-sm text-muted-foreground">
            <Link className="hover:underline" href={ROUTES.manageCourse(id)}>
              {tree.title}
            </Link>
          </p>
        </div>
      </div>
      <CourseWizard course={tree} finalTest={finalTest} />
    </main>
  );
}
