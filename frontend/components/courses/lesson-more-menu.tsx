"use client";

import { MoreVertical } from "lucide-react";
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { ReportContentButton } from "@/components/shared/report-content-button";

interface LessonMoreMenuProps {
  moduleId: string;
}

export function LessonMoreMenu({ moduleId }: LessonMoreMenuProps) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button aria-label="Lesson actions" className="touch-target shrink-0" size="icon" variant="ghost">
          <MoreVertical aria-hidden className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <ReportContentButton asMenuItem contentId={moduleId} contentType="course_module" />
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
