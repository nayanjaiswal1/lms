import { Suspense } from "react";
import { BookOpen } from "lucide-react";
import { Skeleton } from "@/components/ui/skeleton";
import { CourseCard } from "@/components/courses/course-card";
import { getCourses, getEnrollments } from "@/lib/server/courses";

export const metadata = { title: "Courses — MindForge" };

async function CourseGrid() {
  const [courses, enrollments] = await Promise.all([getCourses(), getEnrollments()]);

  const enrolledMap = new Map(enrollments.map((e) => [e.course_id, e]));

  if (courses.length === 0) {
    return (
      <div className="empty-state py-16">
        <BookOpen aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">No courses are available yet.</p>
      </div>
    );
  }

  return (
    <div className="card-grid">
      {courses.map((course) => (
        <CourseCard
          course={course}
          enrolled={enrolledMap.has(course.id)}
          key={course.id}
        />
      ))}
    </div>
  );
}

function CourseGridSkeleton() {
  return (
    <div className="card-grid">
      {Array.from({ length: 6 }).map((_, i) => (
        <Skeleton className="h-64 rounded-lg" key={i} />
      ))}
    </div>
  );
}

export default function CoursesPage() {
  return (
    <main className="page-container py-8">
      <div className="page-header">
        <h1 className="page-title">Courses</h1>
      </div>
      <Suspense fallback={<CourseGridSkeleton />}>
        <CourseGrid />
      </Suspense>
    </main>
  );
}
