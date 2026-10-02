import Link from "next/link";
import { CoursePicker } from "@/components/labs/builder/course-picker";
import { PublishForm } from "@/components/labs/builder/publish-form";
import { currentVerifiedBuild } from "@/lib/labs/builder/build";
import { getCourseSections, getInstructorCourses } from "@/lib/labs/builder/server";
import type { Recipe, RecipeAnalysis } from "@/lib/labs/builder/types";
import ROUTES from "@/lib/routes";

interface PublishStepProps {
  recipe: Recipe;
  analysis: RecipeAnalysis;
  /** ?course= from the URL (the course picker's state). */
  courseParam: string | undefined;
}

/** Publish: one transaction on the backend, only for the verified build of the current composition. */
export async function PublishStep({ recipe, analysis, courseParam }: PublishStepProps) {
  const verified = currentVerifiedBuild(recipe, analysis);
  if (!verified) {
    return (
      <p className="text-sm text-muted-foreground">
        Publishing needs a verified build of the current composition.{" "}
        <Link className="text-primary hover:underline" href={ROUTES.labBuilderRecipe(recipe.id, "build")}>
          Go to Build &amp; verify
        </Link>
      </p>
    );
  }
  const placement = recipe.target_placement;
  const courseId = courseParam ?? placement?.course_id ?? "";
  const [courses, sections] = await Promise.all([
    getInstructorCourses(),
    courseId ? getCourseSections(courseId) : Promise.resolve([]),
  ]);
  const course = courses.find((c) => c.id === courseId);

  return (
    <div className="flex flex-col gap-6">
      {recipe.lab_id && (
        <p className="text-sm text-muted-foreground">
          This lab is already published; publishing again cuts a new version. Sessions in progress keep theirs.
        </p>
      )}
      <CoursePicker defaultCourseId={placement?.course_id ?? ""} options={courses.map((c) => ({ label: c.title, value: c.id }))} />
      {course && (
        <PublishForm
          buildId={verified.id}
          courseId={course.id}
          courseSlug={course.slug}
          defaultSectionId={placement?.course_id === course.id ? placement.section_id : ""}
          key={course.id}
          sectionOptions={sections.map((s) => ({ label: s.title, value: s.id }))}
        />
      )}
    </div>
  );
}
