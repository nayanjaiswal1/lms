"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";

import { BrandMark } from "@/components/shared/brand-mark";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import { LearnerView } from "@/app/demo/tour/learner-view";
import { AdminView } from "@/app/demo/tour/admin-view";

interface DemoShellProps {
  activeView: "learner" | "admin";
}

export function DemoShell({ activeView }: DemoShellProps) {
  const router = useRouter();

  function switchView(v: "learner" | "admin") {
    router.push(`/demo/tour?view=${v}`);
  }

  return (
    <div className="flex min-h-dvh flex-col">
      {/* Demo bar — sticky top */}
      <header
        className="sticky top-0 z-sticky h-14 w-full border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60"
        style={{ zIndex: "var(--z-sticky)" }}
      >
        <div className="page-container flex h-full items-center justify-between">
          {/* Left — brand + demo label */}
          <div className="flex items-center gap-2">
            <BrandMark showName={false} />
            <Badge variant="secondary" className="text-xs">Demo</Badge>
          </div>

          {/* Center — view switcher */}
          <div className="flex items-center gap-1 rounded-full bg-muted p-1">
            <button
              type="button"
              onClick={() => switchView("learner")}
              className={cn(
                "rounded-full px-4 py-1.5 text-sm font-medium transition-colors",
                activeView === "learner"
                  ? "bg-primary text-primary-foreground"
                  : "bg-transparent text-muted-foreground hover:text-foreground",
              )}
            >
              Learner
            </button>
            <button
              type="button"
              onClick={() => switchView("admin")}
              className={cn(
                "rounded-full px-4 py-1.5 text-sm font-medium transition-colors",
                activeView === "admin"
                  ? "bg-primary text-primary-foreground"
                  : "bg-transparent text-muted-foreground hover:text-foreground",
              )}
            >
              Admin
            </button>
          </div>

          {/* Right — exit link */}
          <Link
            href={ROUTES.DEMO}
            className="text-sm text-muted-foreground no-underline hover:text-foreground hover:no-underline"
          >
            Exit demo
          </Link>
        </div>
      </header>

      {/* Main content */}
      <main className="flex-1 pb-24">
        {activeView === "learner" ? <LearnerView /> : <AdminView />}
      </main>

      {/* Conversion bar — fixed bottom */}
      <div className="fixed inset-x-0 bottom-0 border-t border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 safe-bottom" style={{ zIndex: "var(--z-sticky)" }}>
        <div className="page-container flex h-16 flex-col items-center justify-center gap-2 sm:flex-row sm:justify-between">
          <p className="hidden text-sm text-muted-foreground sm:block">
            You&apos;re in demo mode · Your progress won&apos;t be saved
          </p>
          <div className="flex w-full gap-2 sm:w-auto">
            <Button asChild variant="outline" size="sm" className="flex-1 sm:flex-none">
              <Link href={ROUTES.REGISTER}>Create free account</Link>
            </Button>
            <Button asChild size="sm" className="flex-1 sm:flex-none">
              <Link href={ROUTES.REGISTER}>Set up for my team</Link>
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
