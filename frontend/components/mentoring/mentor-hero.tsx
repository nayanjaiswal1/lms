import Link from "next/link";
import { Globe, MessagesSquare, ShieldCheck } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { MentorProfileActions } from "@/components/mentoring/mentor-profile-actions";
import { MessageMentorButton } from "@/components/mentoring/message-mentor-button";
import { ShareProfileButton } from "@/components/mentoring/share-profile-button";
import { StarRating } from "@/components/mentoring/star-rating";
import { formatMentorHeadline } from "@/lib/mentoring/format";
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
  // The booking control, injected by the page rather than imported here.
  // Session booking lives in the `sessions` feature, and a feature-component
  // may not import another feature's components (eslint-plugin-boundaries) —
  // taking it as a slot keeps the primary "Book a session" CTA in the hero
  // where it belongs without opening a cross-feature edge for one button.
  bookingAction?: React.ReactNode;
}

function initials(name: string): string {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w.charAt(0).toUpperCase())
    .join("");
}

const SOCIAL_LINK =
  "touch-target rounded-md text-muted-foreground transition-colors duration-fast ease-smooth hover:bg-accent hover:text-primary";

// The portrait sits on an offset amber plate — the profile's one signature
// flourish. A square crop (not the shared circular ProfileAvatar) because the
// hero needs a larger, editorial portrait treatment than anywhere else.
export function MentorHero({
  mentor,
  isYourMentor,
  assignedCourse,
  canReport,
  ticketId,
  bookingAction,
}: Props) {
  const headline = formatMentorHeadline(mentor.current_role, mentor.years_of_experience);
  const socials = [
    { href: mentor.linkedin, label: "LinkedIn", icon: <LinkedInIcon /> },
    { href: mentor.github, label: "GitHub", icon: <GitHubIcon /> },
    { href: mentor.portfolio, label: "Portfolio", icon: <Globe aria-hidden className="h-5 w-5" /> },
  ].filter((s): s is typeof s & { href: string } => Boolean(s.href));

  return (
    <section aria-labelledby="mentor-name" className="card-raised relative flex flex-col gap-6 sm:p-8 md:flex-row md:items-start md:gap-8">
      <div className="absolute right-3 top-3 sm:right-5 sm:top-5">
        <MentorProfileActions
          canReport={canReport}
          mentorId={mentor.user_id}
          ticketId={ticketId}
          verified={mentor.verified}
        />
      </div>

      <div className="relative mr-2 mb-2 w-fit shrink-0">
        <div aria-hidden className="absolute inset-0 translate-x-2 translate-y-2 rounded-xl border-2 border-primary bg-primary/10" />
        <div className="relative h-28 w-28 overflow-hidden rounded-xl border border-border bg-muted sm:h-36 sm:w-36 md:h-44 md:w-44">
          {mentor.avatar_url ? (
            // oxlint-disable-next-line @next/next/no-img-element -- hero portrait needs the exact square crop, not next/image's layout
            <img alt={`${mentor.name} portrait`} className="h-full w-full object-cover" src={mentor.avatar_url} />
          ) : (
            <div className="flex h-full w-full items-center justify-center bg-primary text-4xl font-semibold text-primary-foreground">
              {initials(mentor.name)}
            </div>
          )}
        </div>
      </div>

      <div className="flex min-w-0 flex-1 flex-col gap-3 md:pr-12">
        <div className="flex flex-col gap-1.5">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="break-words" id="mentor-name">
              {mentor.name}
            </h1>
            {mentor.verified && (
              <Badge className="badge-info" variant="outline">
                <ShieldCheck aria-hidden className="h-3.5 w-3.5" />
                Verified expert
              </Badge>
            )}
            {isYourMentor && <Badge>Your mentor</Badge>}
          </div>
          {headline && <p className="text-lg text-muted-foreground">{headline}</p>}
        </div>

        <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm">
          {mentor.avg_rating !== null ? (
            <span className="flex items-center gap-1.5">
              <StarRating value={mentor.avg_rating} />
              <span className="font-semibold text-foreground">{mentor.avg_rating.toFixed(1)}</span>
              <span className="text-muted-foreground">
                ({mentor.rating_count} rating{mentor.rating_count === 1 ? "" : "s"})
              </span>
            </span>
          ) : (
            <span className="text-muted-foreground">No ratings yet</span>
          )}
          <span className="text-muted-foreground">
            {mentor.mentee_count} active mentee{mentor.mentee_count === 1 ? "" : "s"}
          </span>
        </div>

        {isYourMentor && assignedCourse && (
          <p className="text-sm text-muted-foreground">
            Mentoring you in{" "}
            <Link className="font-medium text-primary hover:underline" href={ROUTES.course(assignedCourse.slug)}>
              {assignedCourse.title}
            </Link>
          </p>
        )}

        {mentor.skills.length > 0 && (
          <ul aria-label="Expertise" className="flex flex-wrap gap-1.5">
            {mentor.skills.map((skill) => (
              <li key={skill}>
                <Badge className="badge-muted px-2.5 py-1 text-sm" variant="outline">
                  {skill}
                </Badge>
              </li>
            ))}
          </ul>
        )}

        <div className="flex flex-col gap-2 pt-2 sm:flex-row sm:flex-wrap sm:items-center">
          {bookingAction}
          <MessageMentorButton className="min-h-11" mentorId={mentor.user_id} variant={bookingAction ? "outline" : "default"} />
          {ticketId && (
            <Button asChild className="min-h-11" variant="outline">
              <Link href={ROUTES.mentoringTicketChat(ticketId)}>
                <MessagesSquare aria-hidden />
                Ticket chat
              </Link>
            </Button>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-1 border-t border-border pt-3">
          <ShareProfileButton className="min-h-11" mentorName={mentor.name} path={ROUTES.mentor(mentor.user_id)} />
          {socials.map((s) => (
            <a aria-label={`${mentor.name} on ${s.label}`} className={SOCIAL_LINK} href={s.href} key={s.label} rel="noopener noreferrer" target="_blank">
              {s.icon}
            </a>
          ))}
        </div>
      </div>
    </section>
  );
}
