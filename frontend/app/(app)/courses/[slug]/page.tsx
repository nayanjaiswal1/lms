import { notFound } from "next/navigation";
import Link from "next/link";
import {
  Award,
  BookOpen,
  CheckCircle2,
  ChevronDown,
  Clock,
  FileText,
  GraduationCap,
  Layers,
  Lock,
  NotebookText,
  Star,
  Tag,
  type LucideIcon,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { CourseProgressBar } from "@/components/courses/course-progress-bar";
import { ReviewForm } from "@/components/courses/review-form";
import { RevisionPlanCard } from "@/components/revision-plan/revision-plan-card";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { FAQPanel } from "@/components/shared/faq-panel";
import { AskQuestion } from "@/components/messaging/ask-question";
import { findCourseBySlug, getCourses, getEnrollments, getCourseTree, getCourseProgress, getMyReview, getFinalTest, getMyCertificates, checkThresholdCertificate } from "@/lib/server/courses";
import { getRevisionPlan } from "@/lib/server/revision-plan";
import { getWikiSpaces } from "@/lib/server/wiki";
import { getCourseFAQs } from "@/lib/server/messaging";
import { enrollAction } from "@/lib/courses/actions";
import { PurchaseCourseButton } from "./purchase-course-button";
import { MODULE_TYPE_ICON, MODULE_TYPE_LABEL } from "@/lib/courses/module-types";
import { moduleStatus, computeCompletion } from "@/lib/courses/progress";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ batchId?: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  return { title: `${slug} — MindForge` };
}

const DIFFICULTY_TEXT_CLASS: Record<string, string> = {
  beginner: "text-success",
  intermediate: "text-warning",
  advanced: "text-destructive",
};

function formatDuration(totalMinutes: number): string {
  if (totalMinutes <= 0) return "Self-paced";
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours === 0) return `${minutes}m`;
  if (minutes === 0) return `${hours}h`;
  return `${hours}h ${minutes}m`;
}

export default async function CourseDetailPage({ params, searchParams }: Props) {
  const { slug } = await params;
  const { batchId } = await searchParams;

  const [courses, enrollments] = await Promise.all([getCourses(), getEnrollments()]);
  const course = findCourseBySlug(courses, enrollments, slug);
  if (!course) notFound();

  const courseId = course.id;
  const enrollment = enrollments.find((e) => e.course_id === courseId);
  const isEnrolled = Boolean(enrollment);

  // Best-effort auto-issue check, run before the certificate list below is
  // fetched (not in the Promise.all — it must land before the read so a
  // certificate issued just now shows up in this same render).
  if (isEnrolled) {
    await checkThresholdCertificate(courseId);
  }

  const [tree, progressSummary, myRating, faqs, wikiSpaces, finalTest, myCertificates] = await Promise.all([
    getCourseTree(courseId).catch(() => null),
    isEnrolled ? getCourseProgress(courseId).catch(() => null) : Promise.resolve(null),
    isEnrolled ? getMyReview(courseId).catch(() => null) : Promise.resolve(null),
    getCourseFAQs(courseId).catch(() => []),
    isEnrolled ? getWikiSpaces().catch(() => []) : Promise.resolve([]),
    isEnrolled ? getFinalTest(courseId) : Promise.resolve(null),
    isEnrolled ? getMyCertificates().catch(() => []) : Promise.resolve([]),
  ]);
  const docsSpace = wikiSpaces.find((s) => s.course_id === courseId) ?? null;
  // Certificates can be earned via final test, mentor award, or completion
  // threshold — never gate "does this learner have a certificate" on
  // whether the course happens to have a final test configured.
  const myCertificate = myCertificates.find((c) => c.course_id === courseId) ?? null;

  const sections = tree?.sections ?? [];
  const allModules = sections.flatMap((s) => s.modules);
  const progress = progressSummary?.modules ?? [];
  const { completed, total } = computeCompletion(allModules.map((m) => m.id), progress);
  const courseComplete = isEnrolled && total > 0 && completed === total;
  const revisionPlan = courseComplete ? await getRevisionPlan(courseId).catch(() => null) : null;
  const totalMinutes = allModules.reduce((sum, m) => sum + (m.estimated_minutes ?? 0), 0);
  const contentLabel = totalMinutes > 0 ? formatDuration(totalMinutes) : course.estimated_hours ? `${course.estimated_hours}h` : "Self-paced";

  const levelColorClass = DIFFICULTY_TEXT_CLASS[course.difficulty] ?? "text-foreground";

  const stats: { icon: LucideIcon; label: string; value: string; colorClass: string }[] = [
    { icon: Layers, label: "Sections", value: String(sections.length), colorClass: "text-primary" },
    { icon: BookOpen, label: "Modules", value: String(allModules.length), colorClass: "text-primary" },
    { icon: Clock, label: "Content", value: contentLabel, colorClass: "text-primary" },
    { icon: GraduationCap, label: "Level", value: course.difficulty, colorClass: levelColorClass },
  ];

  const moduleTypeCounts = allModules.reduce<Record<string, number>>((acc, m) => {
    acc[m.type] = (acc[m.type] ?? 0) + 1;
    return acc;
  }, {});
  const moduleTypeBreakdown = Object.entries(moduleTypeCounts)
    .sort(([, a], [, b]) => b - a)
    .map(([type, count]) => ({
      type,
      count,
      label: MODULE_TYPE_LABEL[type] ?? type,
      Icon: MODULE_TYPE_ICON[type] ?? FileText,
    }));
  const freePreviewCount = allModules.filter((m) => m.is_free_preview).length;

  async function handleEnroll() {
    "use server";
    await enrollAction(courseId);
  }

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Courses", href: ROUTES.COURSES }, { label: course.title }]} />

      <div className="mb-8 flex flex-col gap-6 lg:flex-row lg:items-start lg:gap-8">
        <div className="min-w-0 flex-1">
          <h1 className="section-title">{course.title}</h1>
          <div className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-muted-foreground">
            {course.instructor_name && <span>By {course.instructor_name}</span>}
            {course.avg_rating !== null && (
              <span className="flex items-center gap-1">
                <Star aria-hidden className="h-3.5 w-3.5 fill-primary text-primary" />
                <span className="font-semibold text-foreground">{course.avg_rating.toFixed(1)}</span>
                <span>
                  ({course.review_count} review{course.review_count === 1 ? "" : "s"})
                </span>
              </span>
            )}
          </div>
          <p className="mt-3 max-w-2xl text-muted-foreground">
            {course.description ?? "No description yet — see the curriculum below for what this course covers."}
          </p>

          {(!isEnrolled || course.tags.length > 0) && (
            <div className="mt-4 flex flex-wrap items-center gap-2">
              {!isEnrolled && (
                course.is_free ? (
                  <Badge variant="secondary">Free</Badge>
                ) : (
                  <Badge variant="outline">${(course.price_cents / 100).toFixed(2)}</Badge>
                )
              )}
              {course.tags.length > 0 && (
                <>
                  <Tag aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
                  {course.tags.map((tag) => (
                    <Badge className="text-xs" key={tag} variant="outline">{tag}</Badge>
                  ))}
                </>
              )}
            </div>
          )}
        </div>

        {course.cover_url && (
          <div className="relative aspect-video w-full shrink-0 overflow-hidden rounded-xl border border-border bg-muted lg:w-96">
            {/* eslint-disable-next-line @next/next/no-img-element -- dynamic remote cover, no known dimensions */}
            <img alt={course.title} className="h-full w-full object-cover" src={course.cover_url} />
          </div>
        )}
      </div>

      <div className="flex flex-col gap-8 lg:flex-row lg:items-start lg:gap-12">
        <section className="flex min-w-0 flex-1 flex-col gap-4">
          <h2 className="section-title">Curriculum</h2>

          {sections.length === 0 ? (
            <div className="card-base empty-state">
              <Layers aria-hidden className="empty-state-icon" />
              <p>Curriculum coming soon.</p>
            </div>
          ) : (
            <div className="card-base flex flex-col divide-y divide-border p-0">
              {sections.map((section) => {
                const sectionCompletion = computeCompletion(section.modules.map((m) => m.id), progress);

                return (
                  <details className="group" key={section.id}>
                    <summary className="flex cursor-pointer list-none items-center gap-3 px-6 py-4 transition-colors duration-fast hover:bg-muted">
                      <ChevronDown aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground transition-transform duration-fast group-open:rotate-180" />
                      <span className="min-w-0 flex-1 truncate font-semibold">{section.title}</span>
                      <span className="shrink-0 text-xs text-muted-foreground">
                        {isEnrolled
                          ? `${sectionCompletion.completed}/${section.modules.length}`
                          : `${section.modules.length} module${section.modules.length === 1 ? "" : "s"}`}
                      </span>
                    </summary>

                    {section.modules.length === 0 ? (
                      <p className="border-t border-border px-6 py-3 pl-10 text-sm text-muted-foreground">
                        No modules yet.
                      </p>
                    ) : (
                      <ul className="flex list-none flex-col">
                        {section.modules.map((mod) => {
                          const Icon = MODULE_TYPE_ICON[mod.type] ?? FileText;
                          const status = moduleStatus(mod.id, progress);
                          const isLocked = !isEnrolled && !mod.is_free_preview;

                          const rowContent = (
                            <>
                              {isEnrolled && status === "completed" ? (
                                <CheckCircle2 aria-label="Completed" className="h-4 w-4 shrink-0 text-primary" />
                              ) : (
                                <Icon aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
                              )}
                              <span className="min-w-0 flex-1 truncate">{mod.title}</span>
                              <span className="hidden shrink-0 text-xs text-muted-foreground sm:inline">
                                {MODULE_TYPE_LABEL[mod.type] ?? mod.type}
                              </span>
                              {!isEnrolled && mod.is_free_preview && (
                                <Badge className="shrink-0 text-xs" variant="secondary">Preview</Badge>
                              )}
                              {isLocked ? (
                                <Lock aria-label="Requires enrollment" className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                              ) : (
                                mod.estimated_minutes && (
                                  <span className="shrink-0 text-xs text-muted-foreground">{mod.estimated_minutes}m</span>
                                )
                              )}
                            </>
                          );

                          return (
                            <li className="border-t border-border first:border-t-0" key={mod.id}>
                              {isLocked ? (
                                <div className="flex items-center gap-3 px-6 py-3 pl-10 text-sm text-muted-foreground">
                                  {rowContent}
                                </div>
                              ) : (
                                <Link
                                  className="flex items-center gap-3 px-6 py-3 pl-10 text-sm text-foreground transition-colors duration-fast hover:bg-muted"
                                  href={ROUTES.courseLearnModule(course.slug, mod.id)}
                                >
                                  {rowContent}
                                </Link>
                              )}
                            </li>
                          );
                        })}
                      </ul>
                    )}
                  </details>
                );
              })}
            </div>
          )}

          {batchId && isEnrolled && <AskQuestion batchId={batchId} courseId={courseId} />}

          <FAQPanel faqs={faqs} />
        </section>

        <aside className="w-full lg:w-80 lg:shrink-0">
          <div className="card-raised flex flex-col gap-8 overflow-hidden p-0 lg:sticky lg:top-20">
            <div className="grid grid-cols-2 border-b border-border">
              {stats.map(({ icon: Icon, label, value, colorClass }, i) => (
                <div
                  className={cn(
                    "flex items-center gap-2 px-3 py-2.5 text-xs",
                    i % 2 === 0 && "border-r border-border",
                    i < 2 && "border-b border-border",
                  )}
                  key={label}
                >
                  <Icon aria-hidden className={`h-4 w-4 shrink-0 ${colorClass}`} />
                  <span className={`truncate font-medium capitalize ${colorClass}`}>
                    {label === "Level" || label === "Content" ? value : `${value} ${label}`}
                  </span>
                </div>
              ))}
            </div>

            <div className="flex flex-col gap-8 p-8 pt-0">
              {isEnrolled ? (
                <>
                  <div className="flex flex-col gap-4">
                    <p className="text-sm font-medium text-primary">You&apos;re enrolled</p>
                    <CourseProgressBar completed={completed} total={total || allModules.length} />
                  </div>
                  {myCertificate ? (
                    <Button asChild className="w-full" size="lg" variant="outline">
                      <Link href={ROUTES.certificate(myCertificate.cert_uuid)}>
                        <Award aria-hidden className="h-4 w-4" />
                        View Certificate
                      </Link>
                    </Button>
                  ) : finalTest ? (
                    <Button asChild className="w-full" size="lg">
                      <Link href={ROUTES.courseFinalTest(course.slug)}>
                        <Award aria-hidden className="h-4 w-4" />
                        Take Final Test
                      </Link>
                    </Button>
                  ) : (
                    <Button asChild className="w-full" size="lg">
                      <Link href={ROUTES.courseLearn(course.slug)}>
                        {completed > 0 ? "Continue learning" : "Start learning"}
                      </Link>
                    </Button>
                  )}
                  {courseComplete && <RevisionPlanCard courseId={courseId} plan={revisionPlan} />}
                  {docsSpace && (
                    <Link
                      className="flex items-center gap-2 text-sm text-primary hover:underline"
                      href={ROUTES.wikiSpace(docsSpace.slug)}
                    >
                      <NotebookText aria-hidden className="h-4 w-4" />
                      Course Docs
                    </Link>
                  )}
                  <ReviewForm courseId={courseId} initialRating={myRating} />
                </>
              ) : (
                <>
                  <p className="text-2xl font-bold">
                    {course.is_free ? "Free" : `$${(course.price_cents / 100).toFixed(2)}`}
                  </p>
                  {course.is_free ? (
                    <form action={handleEnroll}>
                      <Button className="w-full" size="lg" type="submit">Enroll for free</Button>
                    </form>
                  ) : (
                    <PurchaseCourseButton courseId={courseId} courseSlug={course.slug} priceCents={course.price_cents} />
                  )}
                </>
              )}

              {moduleTypeBreakdown.length > 0 && (
                <div className="flex flex-col gap-3 border-t border-border pt-6">
                  <p className="text-sm font-medium">This course includes</p>
                  <ul className="flex list-none flex-col gap-2.5">
                    {moduleTypeBreakdown.map(({ type, count, label, Icon }) => (
                      <li className="flex items-center gap-2.5 text-sm text-muted-foreground" key={type}>
                        <Icon aria-hidden className="h-4 w-4 shrink-0 text-primary" />
                        <span>
                          {count} {label}
                          {count === 1 ? "" : "s"}
                        </span>
                      </li>
                    ))}
                    {!isEnrolled && freePreviewCount > 0 && (
                      <li className="flex items-center gap-2.5 text-sm text-muted-foreground">
                        <Tag aria-hidden className="h-4 w-4 shrink-0 text-primary" />
                        <span>
                          {freePreviewCount} free preview{freePreviewCount === 1 ? "" : "s"}
                        </span>
                      </li>
                    )}
                  </ul>
                </div>
              )}
            </div>
          </div>
        </aside>
      </div>
    </main>
  );
}
