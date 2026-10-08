import Link from "next/link";
import {
  BookOpen,
  FlaskConical,
  GraduationCap,
  HelpCircle,
  LayoutDashboard,
  ListChecks,
  type LucideIcon,
} from "lucide-react";

import { BrandMark } from "@/components/shared/brand-mark";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";
import { CoursesDemo } from "@/app/demo/tour/courses-demo";
import { DashboardDemo } from "@/app/demo/tour/dashboard-demo";
import { LabsDemo } from "@/app/demo/tour/labs-demo";
import { QuizDemo } from "@/app/demo/tour/quiz-demo";
import { SheetsDemo } from "@/app/demo/tour/sheets-demo";
import { DEMO_TABS, type DemoLabKind, type DemoTabId } from "@/app/demo/tour/mock-data";

interface DemoShellProps {
  activeTab: DemoTabId;
  courseSlug?: string;
  labKind: DemoLabKind;
  nonce: string;
}

const TAB_ICONS: Record<DemoTabId, LucideIcon> = {
  dashboard: LayoutDashboard,
  courses: GraduationCap,
  labs: FlaskConical,
  quiz: HelpCircle,
  sheets: ListChecks,
};

function tabHref(id: DemoTabId): string {
  return `${ROUTES.DEMO_TOUR}?tab=${id}`;
}

function TabView({ tab, courseSlug, labKind, nonce }: { tab: DemoTabId; courseSlug?: string; labKind: DemoLabKind; nonce: string }) {
  switch (tab) {
    case "courses":
      return <CoursesDemo slug={courseSlug} />;
    case "labs":
      return <LabsDemo kind={labKind} nonce={nonce} />;
    case "quiz":
      return <QuizDemo />;
    case "sheets":
      return <SheetsDemo />;
    default:
      return <DashboardDemo />;
  }
}

export function DemoShell({ activeTab, courseSlug, labKind, nonce }: DemoShellProps) {
  return (
    <div className="app-shell">
      <aside aria-label="Demo navigation" className="app-sidebar">
        <div className="flex items-center gap-2 border-b border-sidebar-border px-5 py-4">
          <BrandMark iconClassName="h-6 w-6" />
          <Badge className="text-xs" variant="secondary">Demo</Badge>
        </div>
        <nav className="flex flex-1 flex-col gap-1 p-3">
          {DEMO_TABS.map(({ id, label }) => {
            const Icon = TAB_ICONS[id];
            return (
              <Link
                aria-current={id === activeTab ? "page" : undefined}
                className={cn(
                  "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium no-underline hover:no-underline",
                  id === activeTab ? "bg-primary/10 text-primary" : "text-muted-foreground hover:text-foreground",
                )}
                href={tabHref(id)}
                key={id}
              >
                <Icon aria-hidden className="h-4 w-4" />
                {label}
              </Link>
            );
          })}
        </nav>
        <Link
          className="flex items-center gap-2 border-t border-sidebar-border px-5 py-4 text-sm text-muted-foreground no-underline hover:text-foreground hover:no-underline"
          href={ROUTES.DEMO}
        >
          <BookOpen aria-hidden className="h-4 w-4" />
          Exit demo
        </Link>
      </aside>

      <div className="app-main">
        <header className="app-header lg:hidden">
          <BrandMark />
          <Badge className="ml-2 text-xs" variant="secondary">Demo</Badge>
        </header>

        <main className="app-content pb-24">
          <TabView courseSlug={courseSlug} labKind={labKind} nonce={nonce} tab={activeTab} />
        </main>

        <div className="sticky bottom-0 z-sticky border-t border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 max-lg:mb-16">
          <div className="flex flex-col items-center justify-center gap-2 px-4 py-3 sm:flex-row sm:justify-between lg:px-8">
            <p className="hidden text-sm text-muted-foreground sm:block">
              Demo mode · Nothing you do here is saved
            </p>
            <div className="flex w-full gap-2 sm:w-auto">
              <Button asChild className="flex-1 sm:flex-none" size="sm" variant="outline">
                <Link href={ROUTES.LOGIN}>Log in</Link>
              </Button>
              <Button asChild className="flex-1 sm:flex-none" size="sm">
                <Link href={ROUTES.REGISTER}>Create free account</Link>
              </Button>
            </div>
          </div>
        </div>
      </div>

      <nav aria-label="Demo navigation" className="bottom-nav">
        {DEMO_TABS.map(({ id, label }) => {
          const Icon = TAB_ICONS[id];
          return (
            <Link
              aria-current={id === activeTab ? "page" : undefined}
              className="bottom-nav-item no-underline hover:no-underline"
              href={tabHref(id)}
              key={id}
            >
              <Icon aria-hidden className="h-5 w-5" />
              <span className="bottom-nav-item-label">{label}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
