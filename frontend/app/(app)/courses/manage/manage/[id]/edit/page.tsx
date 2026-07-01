import { notFound, redirect } from "next/navigation";
import Link from "next/link";
import { getCourseTree } from "@/lib/server/courses";
import { EditCourseForm } from "@/components/instructor/edit-course-form";
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

  return (
    <main className="page-container py-8">
      <div className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Edit course</h1>
          <p className="text-sm text-muted-foreground">
            <Link className="hover:underline" href={ROUTES.manageCourse(id)}>
              {tree.title}
            </Link>
          </p>
        </div>
      </div>

      <div className="mx-auto max-w-2xl">
        <div className="card-base p-6">
          <EditCourseForm course={tree} />
        </div>
      </div>
    </main>
  );
}
