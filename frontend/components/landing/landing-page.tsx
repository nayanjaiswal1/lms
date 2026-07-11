import Link from "next/link";
import {
  ArrowRight,
  Award,
  BookOpen,
  CalendarCheck,
  FlaskConical,
  ListChecks,
  Sparkles,
  Users,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { CourseCard } from "@/components/courses/course-card";
import type { Course } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface LandingPageProps {
  courses: Course[];
  total: number;
}

const FEATURES = [
  {
    icon: BookOpen,
    title: "Structured courses",
    body: "Video lessons, readings, and PDFs organized into sections you can follow at your own pace.",
  },
  {
    icon: FlaskConical,
    title: "Hands-on labs",
    body: "Practice in real coding environments built into every course — no local setup required.",
  },
  {
    icon: ListChecks,
    title: "Assessments and sheets",
    body: "Timed tests and curated problem sheets that show you exactly where you stand.",
  },
  {
    icon: Users,
    title: "Mentoring",
    body: "Book sessions with mentors, message them directly, and get unstuck faster.",
  },
  {
    icon: CalendarCheck,
    title: "Planning built in",
    body: "A calendar and daily plan that turn a course into a schedule you actually keep.",
  },
  {
    icon: Award,
    title: "Certificates",
    body: "Finish a course and earn a certificate you can share with recruiters.",
  },
];

export function LandingPage({ courses, total }: LandingPageProps) {
  return (
    <div className="min-h-dvh bg-background text-foreground">
      <header className="sticky top-0 z-raised border-b border-border bg-background/80 backdrop-blur">
        <nav
          aria-label="Main"
          className="mx-auto flex h-14 w-full max-w-6xl items-center justify-between gap-4 px-4 sm:px-6"
        >
          <Link className="flex items-center gap-2 font-bold" href={ROUTES.HOME}>
            <Sparkles aria-hidden className="h-5 w-5 text-primary" />
            MindForge
          </Link>
          <div className="flex items-center gap-2">
            <Button asChild variant="ghost">
              <Link href={ROUTES.LOGIN}>Log in</Link>
            </Button>
            <Button asChild>
              <Link href={ROUTES.REGISTER}>Get started</Link>
            </Button>
          </div>
        </nav>
      </header>

      <main>
        {/* Hero */}
        <section
          aria-labelledby="hero-heading"
          className="mx-auto w-full max-w-6xl px-4 py-16 text-center sm:px-6 sm:py-24"
        >
          <Badge className="mb-4" variant="outline">
            Learn. Practice. Get hired.
          </Badge>
          <h1
            className="mx-auto max-w-3xl text-balance text-4xl font-bold leading-tight sm:text-5xl"
            id="hero-heading"
          >
            Courses built to take you from lesson to job-ready
          </h1>
          <p className="mx-auto mt-4 max-w-2xl text-pretty text-base text-muted-foreground sm:text-lg">
            MindForge combines instructor-led courses with labs, assessments,
            mentoring, and a daily plan — everything you need to actually finish
            what you start.
          </p>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
            <Button asChild size="lg">
              <Link href={ROUTES.REGISTER}>
                Start learning free
                <ArrowRight aria-hidden className="h-4 w-4" />
              </Link>
            </Button>
            <Button asChild size="lg" variant="outline">
              <Link href="#catalog">Browse courses</Link>
            </Button>
          </div>
        </section>

        {/* Features */}
        <section
          aria-labelledby="features-heading"
          className="border-y border-border bg-muted/30"
        >
          <div className="mx-auto w-full max-w-6xl px-4 py-16 sm:px-6">
            <h2 className="text-center text-2xl font-bold sm:text-3xl" id="features-heading">
              More than videos
            </h2>
            <p className="mx-auto mt-2 max-w-xl text-center text-sm text-muted-foreground">
              Every course plugs into the same toolkit, so learning turns into
              doing.
            </p>
            <ul className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {FEATURES.map(({ icon: Icon, title, body }) => (
                <li
                  className="rounded-xl border border-border bg-card p-6"
                  key={title}
                >
                  <Icon aria-hidden className="h-6 w-6 text-primary" />
                  <h3 className="mt-3 text-base font-semibold">{title}</h3>
                  <p className="mt-1 text-sm text-muted-foreground">{body}</p>
                </li>
              ))}
            </ul>
          </div>
        </section>

        {/* Course catalog */}
        <section
          aria-labelledby="catalog-heading"
          className="mx-auto w-full max-w-6xl scroll-mt-16 px-4 py-16 sm:px-6"
          id="catalog"
        >
          <div className="flex flex-wrap items-end justify-between gap-2">
            <div>
              <h2 className="text-2xl font-bold sm:text-3xl" id="catalog-heading">
                Ready-to-enroll courses
              </h2>
              <p className="mt-2 text-sm text-muted-foreground">
                {total > 0
                  ? `${total} published course${total === 1 ? "" : "s"} from instructors on MindForge.`
                  : "Published courses from instructors on MindForge."}
              </p>
            </div>
            <Button asChild variant="ghost">
              <Link href={ROUTES.REGISTER}>
                Join to enroll
                <ArrowRight aria-hidden className="h-4 w-4" />
              </Link>
            </Button>
          </div>

          {courses.length > 0 ? (
            <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {courses.map((course) => (
                <CourseCard course={course} href={ROUTES.REGISTER} key={course.id} />
              ))}
            </div>
          ) : (
            <div className="mt-8 rounded-xl border border-dashed border-border p-10 text-center">
              <BookOpen aria-hidden className="mx-auto h-8 w-8 text-muted-foreground" />
              <p className="mt-3 text-sm text-muted-foreground">
                The catalog is being stocked. Create a free account and be the
                first to know when courses go live.
              </p>
              <Button asChild className="mt-4">
                <Link href={ROUTES.REGISTER}>Create free account</Link>
              </Button>
            </div>
          )}
        </section>

        {/* Bottom CTA */}
        <section aria-labelledby="cta-heading" className="border-t border-border">
          <div className="mx-auto w-full max-w-6xl px-4 py-16 text-center sm:px-6">
            <h2 className="text-2xl font-bold sm:text-3xl" id="cta-heading">
              Start your first course today
            </h2>
            <p className="mx-auto mt-2 max-w-xl text-sm text-muted-foreground">
              Free to sign up. Enroll in free courses instantly, or buy paid
              ones when you are ready.
            </p>
            <Button asChild className="mt-6" size="lg">
              <Link href={ROUTES.REGISTER}>
                Get started
                <ArrowRight aria-hidden className="h-4 w-4" />
              </Link>
            </Button>
          </div>
        </section>
      </main>

      <footer className="border-t border-border">
        <div className="mx-auto flex w-full max-w-6xl flex-wrap items-center justify-between gap-4 px-4 py-8 text-sm text-muted-foreground sm:px-6">
          <p>© {new Date().getFullYear()} MindForge</p>
          <nav aria-label="Footer" className="flex items-center gap-4">
            <Link className="hover:text-foreground" href={ROUTES.LOGIN}>
              Log in
            </Link>
            <Link className="hover:text-foreground" href={ROUTES.REGISTER}>
              Register
            </Link>
          </nav>
        </div>
      </footer>
    </div>
  );
}
