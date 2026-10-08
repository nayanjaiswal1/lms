import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, FlaskConical, GraduationCap, ListChecks } from "lucide-react";

import { BrandMark } from "@/components/shared/brand-mark";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Live demo",
  description: "Explore MindForge with realistic mock data — no account needed.",
};

const HIGHLIGHTS = [
  { icon: GraduationCap, label: "Courses & quizzes" },
  { icon: FlaskConical,  label: "Hands-on debug labs" },
  { icon: ListChecks,    label: "Problem sheets" },
] as const;

export default function DemoPage() {
  return (
    <main className="flex min-h-dvh flex-col">
      <header className="flex items-center px-6 py-5 sm:px-8">
        <Link aria-label="Home" className="hover:no-underline" href={ROUTES.HOME}>
          <BrandMark />
        </Link>
      </header>

      <div className="flex flex-1 flex-col items-center justify-center px-4 py-16 sm:px-6">
        <div className="flex w-full max-w-xl flex-col items-center gap-8 text-center">
          <span className="rounded-full border border-border px-3 py-1 text-xs text-muted-foreground">
            No account needed · Free to explore
          </span>

          <div className="flex flex-col gap-3">
            <h1>See MindForge in action</h1>
            <p className="mx-auto max-w-md text-muted-foreground">
              Click through the real dashboard layout and work through a course, fix a broken app in a debug lab, take a quiz and track a problem sheet. Nothing is saved.
            </p>
          </div>

          <div className="flex flex-wrap items-center justify-center gap-x-6 gap-y-3">
            {HIGHLIGHTS.map(({ icon: Icon, label }, idx) => (
              <span className="flex items-center gap-2 text-sm text-muted-foreground" key={label}>
                {idx > 0 && <span aria-hidden className="hidden sm:block text-border">·</span>}
                <Icon aria-hidden className="h-4 w-4 shrink-0" />
                {label}
              </span>
            ))}
          </div>

          <Button asChild size="lg">
            <Link href={ROUTES.DEMO_TOUR}>
              Start exploring
              <ArrowRight aria-hidden className="h-4 w-4" />
            </Link>
          </Button>

          <p className="text-sm text-muted-foreground">
            Already have an account?{" "}
            <Link className="font-medium" href={ROUTES.LOGIN}>
              Log in
            </Link>
          </p>
        </div>
      </div>
    </main>
  );
}
