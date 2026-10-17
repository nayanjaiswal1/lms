"use client";

import Link from "next/link";
import { HoverCard, HoverCardContent, HoverCardTrigger } from "@/components/ui/hover-card";
import { ProfileAvatar } from "@/components/shared/profile-avatar";
import ROUTES from "@/lib/routes";
import type { InstructorPreview } from "@/lib/server/courses";

interface InstructorHoverProps {
  name: string;
  instructor?: InstructorPreview;
}

// Author name on a course card with a hover/focus preview. Sits above the
// card's full-area link overlay (relative z-raised) so hovering reaches it.
export function InstructorHover({ name, instructor }: InstructorHoverProps) {
  const label = <span className="truncate">By {name}</span>;
  if (!instructor) return label;

  return (
    <HoverCard closeDelay={100} openDelay={250}>
      <HoverCardTrigger asChild>
        <button className="relative z-raised min-w-0 cursor-default truncate text-left hover:text-foreground hover:underline focus-visible:text-foreground" type="button">
          By {name}
        </button>
      </HoverCardTrigger>
      <HoverCardContent>
        <div className="flex flex-col gap-3">
          <div className="flex min-w-0 items-center gap-3">
            <ProfileAvatar avatarUrl={instructor.avatar_url} name={name} size="sm" />
            <div className="min-w-0">
              <p className="truncate font-medium text-foreground">{name}</p>
              {instructor.headline && (
                <p className="truncate text-xs text-muted-foreground">{instructor.headline}</p>
              )}
            </div>
          </div>
          {instructor.bio && <p className="line-clamp-3 text-sm text-muted-foreground">{instructor.bio}</p>}
          <div className="flex items-center justify-between text-xs text-muted-foreground">
            <span>
              {instructor.course_count} published course{instructor.course_count === 1 ? "" : "s"}
            </span>
            {instructor.profile_slug && (
              <Link className="font-medium text-primary hover:underline" href={ROUTES.publicProfile(instructor.profile_slug)}>
                View profile
              </Link>
            )}
          </div>
        </div>
      </HoverCardContent>
    </HoverCard>
  );
}
