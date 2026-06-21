import Link from "next/link"
import { Copy } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { ProfileAvatar } from "@/components/profile/profile-avatar"
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
}

export function ProfileHeader({ profile }: Props) {
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
    <div className="card-base p-6 flex flex-col items-center gap-4 sm:flex-row sm:items-start sm:gap-6">
      <ProfileAvatar avatarUrl={avatar_url} editable={false} name={name} size="lg" />

      <div className="flex flex-col items-center sm:items-start gap-1 min-w-0 flex-1">
        <h1 className="text-xl font-bold truncate max-w-full">{name}</h1>

        {display_name && (
          <p className="text-sm text-muted-foreground">@{display_name}</p>
        )}

        <div className="flex flex-wrap gap-2 mt-1">
          {current_role && (
            <Badge variant="secondary">{current_role}</Badge>
          )}
          {experience_level && (
            <Badge className="capitalize" variant="outline">
              {experience_level}
            </Badge>
          )}
        </div>

        {profile_slug && (
          <div className="flex items-center gap-1.5 mt-1">
            <span className="text-xs text-muted-foreground">
              /u/{profile_slug}
            </span>
            <Link
              aria-label="Copy profile link"
              className="text-muted-foreground hover:text-foreground transition-colors duration-fast"
              href={`/u/${profile_slug}`}
            >
              <Copy size={12} />
            </Link>
          </div>
        )}

        <div className="w-full mt-3 space-y-1">
          <div className="flex items-center justify-between">
            <span className="text-xs text-muted-foreground">Profile {pct}% complete</span>
          </div>
          <div className="h-1.5 w-full bg-muted rounded-full overflow-hidden">
            { }
            {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width requires inline style; no Tailwind utility exists for runtime percentage values */}
            <div className="h-full bg-primary rounded-full transition-all duration-slow" style={{ width: `${pct}%` }} />
          </div>
        </div>
      </div>
    </div>
  )
}
