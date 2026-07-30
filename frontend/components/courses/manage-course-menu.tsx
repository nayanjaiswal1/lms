"use client";

import Link from "next/link";
import { MoreVertical } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import ROUTES from "@/lib/routes";

interface ManageCourseMenuProps {
  courseSlug: string;
  courseTitle: string;
  published: boolean;
  canEdit: boolean;
  canViewAnalytics: boolean;
}

export function ManageCourseMenu({
  courseSlug,
  courseTitle,
  published,
  canEdit,
  canViewAnalytics,
}: ManageCourseMenuProps) {
  if (!canEdit && !canViewAnalytics && !published) return null;

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          aria-label={`${courseTitle} options`}
          className="touch-target"
          size="icon"
          variant="ghost"
          onClick={(e) => e.stopPropagation()}
        >
          <MoreVertical aria-hidden className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" onClick={(e) => e.stopPropagation()}>
        {canEdit && (
          <DropdownMenuItem asChild>
            <Link href={ROUTES.courseEditSettings(courseSlug)}>Edit</Link>
          </DropdownMenuItem>
        )}
        {published && (
          <DropdownMenuItem asChild>
            <Link href={ROUTES.course(courseSlug)} rel="noopener noreferrer" target="_blank">
              Preview as student
            </Link>
          </DropdownMenuItem>
        )}
        {canViewAnalytics && (
          <DropdownMenuItem asChild>
            <Link href={ROUTES.courseEditAnalytics(courseSlug)}>Analytics</Link>
          </DropdownMenuItem>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
