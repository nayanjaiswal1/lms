import Link from "next/link";
import { MessageCircle, Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ProfileAvatar } from "@/components/shared/profile-avatar";
import { MessageMentorButton } from "@/components/mentoring/message-mentor-button";
import { StarRating } from "@/components/mentoring/star-rating";
import type { MentorDirectoryEntry } from "@/lib/server/mentoring";
import { formatMentorHeadline } from "@/lib/mentoring/format";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

const VISIBLE_SKILLS = 4;

interface MentorDirectoryCardProps {
  mentor: MentorDirectoryEntry;
  chatTicketId: string | undefined;
  activeSkill: string;
}

export function MentorDirectoryCard({ mentor, chatTicketId, activeSkill }: MentorDirectoryCardProps) {
  const headline = formatMentorHeadline(mentor.current_role, mentor.years_of_experience);
  // The filtered-on skill is pulled to the front so the reason a card matched
  // is always visible, even when it sits past the visible-chip cutoff.
  const skills = [...mentor.skills].sort(
    (a, b) => Number(b.toLowerCase() === activeSkill) - Number(a.toLowerCase() === activeSkill),
  );
  const hiddenSkills = skills.length - VISIBLE_SKILLS;

  return (
    <article
      className={cn(
        "card-base flex h-full flex-col gap-4 transition-shadow duration-fast ease-smooth hover:shadow-raised",
        chatTicketId && "border-primary/40",
      )}
    >
      <div className="flex min-w-0 items-start gap-3">
        <ProfileAvatar avatarUrl={mentor.avatar_url} name={mentor.name} size="md" />
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <h3 className="truncate text-base font-semibold">
            <Link className="text-foreground hover:text-primary" href={ROUTES.mentor(mentor.user_id)}>
              {mentor.name}
            </Link>
          </h3>
          {headline && <p className="line-clamp-2 text-sm text-muted-foreground">{headline}</p>}
          {chatTicketId && <Badge className="mt-1">Your mentor</Badge>}
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground">
        {mentor.avg_rating !== null ? (
          <span className="flex items-center gap-1.5">
            <StarRating size="sm" value={mentor.avg_rating} />
            <span className="font-semibold text-foreground">{mentor.avg_rating.toFixed(1)}</span>
            <span>({mentor.rating_count})</span>
          </span>
        ) : (
          <span>No ratings yet</span>
        )}
        <span className="flex items-center gap-1">
          <Users aria-hidden className="h-3.5 w-3.5" />
          {mentor.mentee_count} mentee{mentor.mentee_count === 1 ? "" : "s"}
        </span>
      </div>

      {mentor.bio && <p className="line-clamp-2 text-sm text-foreground">{mentor.bio}</p>}

      {skills.length > 0 && (
        <ul aria-label="Expertise" className="flex flex-wrap gap-1.5">
          {skills.slice(0, VISIBLE_SKILLS).map((skill) => (
            <li key={skill}>
              <Badge
                className={skill.toLowerCase() === activeSkill ? "badge-info" : "badge-muted"}
                variant="outline"
              >
                {skill}
              </Badge>
            </li>
          ))}
          {hiddenSkills > 0 && (
            <li>
              <Badge className="badge-muted" variant="outline">
                +{hiddenSkills} more
              </Badge>
            </li>
          )}
        </ul>
      )}

      <div className="mt-auto flex flex-col gap-2 pt-2 sm:flex-row">
        {chatTicketId ? (
          <Button asChild className="min-h-11 flex-1">
            <Link href={ROUTES.mentoringTicketChat(chatTicketId)}>
              <MessageCircle aria-hidden />
              Chat
            </Link>
          </Button>
        ) : (
          <MessageMentorButton className="min-h-11 flex-1" mentorId={mentor.user_id} variant="default" />
        )}
        <Button asChild className="min-h-11 flex-1" variant="outline">
          <Link aria-label={`View ${mentor.name}'s profile`} href={ROUTES.mentor(mentor.user_id)}>
            View profile
          </Link>
        </Button>
      </div>
    </article>
  );
}
