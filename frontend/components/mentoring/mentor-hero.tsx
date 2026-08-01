import Link from "next/link";
import { Globe, ShieldCheck, Star } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { MentorProfileActions } from "@/components/mentoring/mentor-profile-actions";
import { ScheduleSessionButton } from "@/components/mentoring/schedule-session-button";
import { ShareProfileButton } from "@/components/mentoring/share-profile-button";
import type { MentorProfile } from "@/lib/server/mentoring";
import ROUTES from "@/lib/routes";

// lucide-react dropped brand marks — inline SVGs, same pattern as
// components/auth/social-login-buttons.tsx's GithubIcon.
function LinkedInIcon() {
  return (
    <svg aria-hidden className="h-5 w-5 shrink-0" fill="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path d="M19 3a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h14m-.5 15.5v-5.3a3.26 3.26 0 0 0-3.26-3.26c-.85 0-1.84.52-2.32 1.3v-1.11h-2.79v8.37h2.79v-4.93c0-.77.62-1.4 1.39-1.4a1.4 1.4 0 0 1 1.4 1.4v4.93h2.79M6.88 8.56a1.68 1.68 0 0 0 1.68-1.68c0-.93-.75-1.69-1.68-1.69a1.69 1.69 0 0 0-1.69 1.69c0 .93.76 1.68 1.69 1.68m1.39 9.94v-8.37H5.5v8.37h2.77z" />
    </svg>
  );
}

function GitHubIcon() {
  return (
    <svg aria-hidden className="h-5 w-5 shrink-0" fill="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path d="M12 2A10 10 0 0 0 2 12c0 4.42 2.87 8.17 6.84 9.5.5.08.66-.23.66-.5v-1.69c-2.77.6-3.36-1.34-3.36-1.34-.46-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.87 1.52 2.34 1.07 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.92 0-1.11.38-2 1.03-2.71-.1-.25-.45-1.29.1-2.64 0 0 .84-.27 2.75 1.02.79-.22 1.65-.33 2.5-.33.85 0 1.71.11 2.5.33 1.91-1.29 2.75-1.02 2.75-1.02.55 1.35.2 2.39.1 2.64.65.71 1.03 1.6 1.03 2.71 0 3.82-2.34 4.66-4.57 4.91.36.31.69.92.69 1.85V21c0 .27.16.59.67.5C19.14 20.16 22 16.42 22 12A10 10 0 0 0 12 2z" />
    </svg>
  );
}

interface Props {
  mentor: MentorProfile;
  isYourMentor: boolean;
  assignedCourse?: { slug: string; title: string };
  canReport: boolean;
  ticketId?: string;
}

function initials(name: string): string {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w.charAt(0).toUpperCase())
    .join("");
}

function RatingStars({ rating, count }: { rating: number; count: number }) {
  const rounded = Math.round(rating);
  return (
    <p className="flex items-center gap-1.5 text-sm">
      <span aria-hidden className="flex items-center gap-0.5 text-primary">
        {[1, 2, 3, 4, 5].map((n) => (
          <Star className="h-4 w-4" fill={n <= rounded ? "currentColor" : "none"} key={n} />
        ))}
      </span>
      <span className="font-semibold text-foreground">{rating.toFixed(1)}</span>
      <span className="text-muted-foreground">
        ({count} rating{count === 1 ? "" : "s"})
      </span>
    </p>
  );
}

// The mockup's glass hero card — bigger square (not circular) portrait,
// verified badge, headline name, and the CTA row. Kept as its own component
// since it's a materially different avatar/layout treatment than the shared
// ProfileAvatar (circular) used everywhere else in the app.
export function MentorHero({ mentor, isYourMentor, assignedCourse, canReport, ticketId }: Props) {
  return (
    <section className="relative flex flex-col items-center gap-6 rounded-xl border border-border bg-card/60 p-6 backdrop-blur-xl sm:p-8 md:flex-row md:items-end">
      <div className="absolute right-4 top-4 sm:right-6 sm:top-6">
        <MentorProfileActions canReport={canReport} mentorId={mentor.user_id} ticketId={ticketId} verified={mentor.verified} />
      </div>

      <div className="h-40 w-40 shrink-0 overflow-hidden rounded-xl border-2 border-primary/20 sm:h-48 sm:w-48 md:h-56 md:w-56">
        {mentor.avatar_url ? (
          // eslint-disable-next-line @next/next/no-img-element -- hero portrait needs the exact glass-card crop, not next/image's layout
          <img alt={`${mentor.name} portrait`} className="h-full w-full object-cover" src={mentor.avatar_url} />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-primary text-4xl font-semibold text-primary-foreground">
            {initials(mentor.name)}
          </div>
        )}
      </div>

      <div className="flex min-w-0 flex-1 flex-col items-center gap-2 text-center md:items-start md:pb-2 md:pr-10 md:text-left">
        {mentor.verified && (
          <span className="flex items-center gap-1.5 text-sm font-bold uppercase tracking-wide text-primary">
            <ShieldCheck aria-hidden className="h-4 w-4" />
            Verified expert
          </span>
        )}

        <div className="flex flex-wrap items-center justify-center gap-2 md:justify-start">
          <h1 className="text-4xl font-bold leading-tight tracking-tight sm:text-5xl">{mentor.name}</h1>
          {isYourMentor && <Badge>Your mentor</Badge>}
        </div>

        {mentor.current_role && (
          <p className="text-lg text-muted-foreground">
            {mentor.current_role}
            {mentor.years_of_experience !== null &&
              ` • ${mentor.years_of_experience} yr${mentor.years_of_experience === 1 ? "" : "s"} experience`}
          </p>
        )}

        {mentor.avg_rating !== null && <RatingStars count={mentor.rating_count} rating={mentor.avg_rating} />}

        {isYourMentor && assignedCourse && (
          <p className="text-sm text-muted-foreground">
            Mentoring you in{" "}
            <Link className="text-primary hover:underline" href={ROUTES.course(assignedCourse.slug)}>
              {assignedCourse.title}
            </Link>
          </p>
        )}

        <div className="flex flex-wrap items-center justify-center gap-3 pt-2 md:justify-start">
          <ScheduleSessionButton attendeeId={mentor.user_id} size="default" triggerLabel="Book a session" variant="default" />
          <ShareProfileButton mentorName={mentor.name} path={ROUTES.mentor(mentor.user_id)} />
          {(mentor.linkedin || mentor.github || mentor.portfolio) && (
            <div className="ml-1 flex items-center gap-3">
              {mentor.linkedin && (
                <a
                  aria-label="LinkedIn"
                  className="text-muted-foreground transition-colors duration-fast hover:text-primary"
                  href={mentor.linkedin}
                  rel="noopener noreferrer"
                  target="_blank"
                >
                  <LinkedInIcon />
                </a>
              )}
              {mentor.github && (
                <a
                  aria-label="GitHub"
                  className="text-muted-foreground transition-colors duration-fast hover:text-primary"
                  href={mentor.github}
                  rel="noopener noreferrer"
                  target="_blank"
                >
                  <GitHubIcon />
                </a>
              )}
              {mentor.portfolio && (
                <a
                  aria-label="Portfolio"
                  className="text-muted-foreground transition-colors duration-fast hover:text-primary"
                  href={mentor.portfolio}
                  rel="noopener noreferrer"
                  target="_blank"
                >
                  <Globe aria-hidden className="h-5 w-5" />
                </a>
              )}
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
