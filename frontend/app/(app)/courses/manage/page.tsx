import { Suspense } from "react";
import Link from "next/link";
import { Plus, BookOpen } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { getCourses } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

export const metadata = { title: "My Courses — MindForge" };

async function InstructorCourseList() {
  const courses = await getCourses("?role=instructor");

  if (courses.length === 0) {
    return (
      <div className="empty-state py-16">
        <BookOpen aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">You have not created any courses yet.</p>
        <Button asChild className="mt-4">
          <Link href={ROUTES.MANAGE_COURSES_NEW}>Create your first course</Link>
        </Button>
      </div>
    );
  }

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-xs text-muted-foreground">
            <th className="pb-2 font-medium">Title</th>
            <th className="pb-2 font-medium">Difficulty</th>
            <th className="pb-2 font-medium">Status</th>
            <th className="pb-2 font-medium">Created</th>
            <th className="pb-2 font-medium">Actions</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {courses.map((course) => (
            <tr key={course.id}>
              <td className="py-3 pr-4 font-medium">
                <Link className="hover:underline" href={ROUTES.manageCourse(course.id)}>
                  {course.title}
                </Link>
              </td>
              <td className="py-3 pr-4 capitalize text-muted-foreground">{course.difficulty}</td>
              <td className="py-3 pr-4">
                <Badge variant={course.status === "published" ? "default" : "secondary"}>
                  {course.status}
                </Badge>
              </td>
              <td className="py-3 pr-4 text-muted-foreground">
                {new Date(course.created_at).toLocaleDateString()}
              </td>
              <td className="py-3">
                <Link className="text-primary hover:underline text-xs" href={ROUTES.manageCourseAnalytics(course.id)}>
                  Analytics
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default function InstructorCoursesPage() {
  return (
    <main className="page-container py-8">
      <div className="page-header">
        <h1 className="page-title">My Courses</h1>
        <Button asChild>
          <Link href={ROUTES.MANAGE_COURSES_NEW}>
            <Plus aria-hidden className="mr-2 h-4 w-4" />
            New course
          </Link>
        </Button>
      </div>
      <Suspense fallback={<Skeleton className="h-64 rounded-lg" />}>
        <InstructorCourseList />
      </Suspense>
    </main>
  );
}
