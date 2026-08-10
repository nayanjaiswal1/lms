"use client";

import { MoreVertical } from "lucide-react";
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { DeleteSelfCourseModuleButton } from "@/components/courses/delete-self-course-module-button";
import { ReportContentButton } from "@/components/shared/report-content-button";

interface LessonMoreMenuProps {
  courseSlug: string;
  moduleId: string;
  moduleTitle: string;
  fallbackModuleId: string | null;
  isSelfCourse: boolean;
}

export function LessonMoreMenu({
  courseSlug,
  moduleId,
  moduleTitle,
  fallbackModuleId,
  isSelfCourse,
}: LessonMoreMenuProps) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button aria-label="Lesson actions" className="touch-target shrink-0" size="icon" variant="ghost">
          <MoreVertical aria-hidden className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {isSelfCourse && (
          <DeleteSelfCourseModuleButton
            asMenuItem
            courseSlug={courseSlug}
            fallbackModuleId={fallbackModuleId}
            moduleId={moduleId}
            moduleTitle={moduleTitle}
          />
        )}
        {!isSelfCourse && (
          <ReportContentButton asMenuItem contentId={moduleId} contentType="course_module" />
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
