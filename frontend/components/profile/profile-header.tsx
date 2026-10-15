import Link from "next/link"
import { ExternalLink } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { ProfileAvatar } from "@/components/shared/profile-avatar"
import ROUTES from "@/lib/routes"
import type { Profile } from "@/lib/profile/types"

interface Props {
  profile: Pick<
    Profile,
    | "name"
    | "avatar_url"
    | "display_name"
    | "current_role"
    | "experience_level"
    | "profile_slug"
    | "completion_score"
  >
  uploadAction?: (formData: FormData) => Promise<void>
}

// Ring sits 8px outside the 96px avatar: 112px box, 4px stroke.
const RING_RADIUS = 54
const RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS

export function ProfileHeader({ profile, uploadAction }: Props) {
  const {
    name,
    avatar_url,
    display_name,
    current_role,
    experience_level,
    profile_slug,
    completion_score,
  } = profile

  const pct = Math.min(100, Math.max(0, completion_score))

  return (
    <header className="card-raised flex flex-col items-center gap-5 text-center sm:flex-row sm:items-center sm:gap-6 sm:text-left">
      <div className="relative flex h-28 w-28 shrink-0 items-center justify-center">
        <svg aria-hidden="true" className="absolute inset-0 h-full w-full -rotate-90" viewBox="0 0 112 112">
          <circle className="stroke-muted" cx="56" cy="56" fill="none" r={RING_RADIUS} strokeWidth="4" />
          <circle
            className="stroke-primary transition-all duration-slow ease-smooth"
            cx="56"
            cy="56"
            fill="none"
            r={RING_RADIUS}
            strokeDasharray={RING_CIRCUMFERENCE}
            strokeDashoffset={RING_CIRCUMFERENCE * (1 - pct / 100)}
            strokeLinecap="round"
            strokeWidth="4"
          />
        </svg>
        <ProfileAvatar
          avatarUrl={avatar_url}
          editable={Boolean(uploadAction)}
          name={name}
          size="lg"
          uploadAction={uploadAction}
        />
      </div>

      <div className="flex min-w-0 flex-1 flex-col items-center gap-2 sm:items-start">
        <div className="min-w-0 max-w-full">
          <h2 className="section-title truncate text-foreground">{name}</h2>
          {display_name && (
            <p className="truncate text-sm text-muted-foreground">@{display_name}</p>
          )}
        </div>

        {(current_role || experience_level) && (
          <div className="flex flex-wrap justify-center gap-2 sm:justify-start">
            {current_role && <Badge variant="secondary">{current_role}</Badge>}
            {experience_level && (
              <Badge className="capitalize" variant="outline">
                {experience_level}
              </Badge>
            )}
          </div>
        )}

        <p className="text-sm text-muted-foreground">
          <span className="font-semibold text-primary">{pct}%</span> profile complete
        </p>
      </div>

      {profile_slug && (
        <Link
          className="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-md border border-border px-4 text-sm font-medium text-foreground transition-colors duration-fast ease-smooth hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring sm:w-auto sm:self-start"
          href={ROUTES.publicProfile(profile_slug)}
        >
          <ExternalLink aria-hidden="true" className="h-4 w-4" />
          View public profile
        </Link>
      )}
    </header>
  )
}
