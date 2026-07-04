"use client";

import { useRef, useState } from "react";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { BrandMark } from "@/components/shared/brand-mark";
import { CourseSidebar } from "@/components/courses/course-sidebar";
import type { CourseTree, ModuleProgress } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface Props {
  course: CourseTree;
  currentModuleId: string;
  isEnrolled: boolean;
  progress: ModuleProgress[];
}

const MIN_WIDTH = 240;
const MAX_WIDTH = 480;
const DEFAULT_WIDTH = 288;

// Desktop rail for the course-learn page — flush against the viewport edge
// (replaces the product sidebar there) with its own back-to-dashboard link,
// course module tree, and a drag handle to resize.
export function CourseSidebarRail({ course, currentModuleId, isEnrolled, progress }: Props) {
  const [width, setWidth] = useState(DEFAULT_WIDTH);
  const dragStart = useRef<{ x: number; width: number } | null>(null);

  function handlePointerDown(e: React.PointerEvent<HTMLDivElement>) {
    e.currentTarget.setPointerCapture(e.pointerId);
    dragStart.current = { x: e.clientX, width };
  }

  function handlePointerMove(e: React.PointerEvent<HTMLDivElement>) {
    if (!dragStart.current) return;
    const next = dragStart.current.width + (e.clientX - dragStart.current.x);
    setWidth(Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, next)));
  }

  function handlePointerUp(e: React.PointerEvent<HTMLDivElement>) {
    dragStart.current = null;
    e.currentTarget.releasePointerCapture(e.pointerId);
  }

  return (
    <aside
      className="relative hidden shrink-0 lg:-my-8 lg:-ml-8 lg:sticky lg:top-0 lg:flex lg:h-dvh lg:flex-col lg:overflow-hidden lg:border-r lg:border-sidebar-border lg:bg-sidebar"
      // eslint-disable-next-line no-restricted-syntax -- resizable rail width is user-driven, not expressible as a static class
      style={{ width }}
    >
      <Link
        aria-label="Back to dashboard"
        className="flex shrink-0 items-center gap-2 border-b border-sidebar-border px-5 py-5 transition-colors duration-fast hover:bg-muted"
        href={ROUTES.DASHBOARD}
      >
        <ArrowLeft aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
        <BrandMark />
      </Link>

      <div className="overflow-y-auto">
        <CourseSidebar course={course} currentModuleId={currentModuleId} isEnrolled={isEnrolled} progress={progress} />
      </div>

      <div
        aria-label="Resize course sidebar"
        aria-orientation="vertical"
        className="absolute inset-y-0 right-0 z-raised w-1.5 cursor-col-resize touch-none hover:bg-primary/40"
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        role="separator"
        tabIndex={0}
      />
    </aside>
  );
}
