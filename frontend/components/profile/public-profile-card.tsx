"use client"

import { useState } from "react"
import { ExternalLink, Globe, Link2, Copy, Check } from "lucide-react"
import Link from "next/link"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { ProfileAvatar } from "@/components/profile/profile-avatar"
import { cn } from "@/lib/utils"
import type { PublicProfile, Skill } from "@/lib/profile/types"

// Inline client sub-component — only interactive piece in this file
function CopyButton({ url }: { url: string }) {
  const [copied, setCopied] = useState(false)

  async function handleCopy() {
    await navigator.clipboard.writeText(url)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <Button
      aria-label="Copy profile URL"
      className="gap-1.5"
      size="sm"
      variant="outline"
      onClick={handleCopy}
    >
      {copied ? (
        <Check aria-hidden="true" size={14} />
      ) : (
        <Copy aria-hidden="true" size={14} />
      )}
      {copied ? "Copied!" : "Copy Link"}
    </Button>
  )
}

const LEVEL_DOT: Record<Skill["skill_level"], string> = {
  beginner:     "bg-muted-foreground",
  intermediate: "bg-primary/60",
  advanced:     "bg-primary",
}

interface Props {
  profile: PublicProfile
}

export function PublicProfileCard({ profile }: Props) {
  const {
    name,
    avatar_url,
    display_name,
    bio,
    experience_level,
    current_role,
    skills,
    stats,
    social_links,
    profile_slug,
  } = profile

  const profileUrl =
    typeof window !== "undefined"
      ? `${window.location.origin}/u/${profile_slug}`
      : `/u/${profile_slug}`

  return (
    <article aria-label={`${name}'s public profile`} className="card-base p-6 space-y-6">
      {/* Header */}
      <div className="flex flex-col items-center gap-4 sm:flex-row sm:items-start sm:gap-5">
        <ProfileAvatar avatarUrl={avatar_url} editable={false} name={name} size="lg" />

        <div className="flex flex-col items-center sm:items-start gap-1 min-w-0">
          <h1 className="text-xl font-bold">{name}</h1>

          {display_name && (
            <p className="text-sm text-muted-foreground">@{display_name}</p>
          )}

          {bio && (
            <p className="text-sm text-muted-foreground mt-1 max-w-prose">{bio}</p>
          )}

          <div className="flex flex-wrap gap-2 mt-2">
            {experience_level && (
              <Badge className="capitalize" variant="outline">
                {experience_level}
              </Badge>
            )}
            {current_role && (
              <Badge variant="secondary">{current_role}</Badge>
            )}
          </div>
        </div>
      </div>

      {/* Skills */}
      {skills && skills.length > 0 && (
        <section aria-label="Skills">
          <h2 className="text-sm font-medium text-muted-foreground uppercase tracking-wide mb-3">
            Skills
          </h2>
          <div className="flex flex-wrap gap-2">
            {skills.map((skill) => (
              <Badge className="gap-1.5" key={skill.id} variant="secondary">
                <span
                  aria-label={skill.skill_level}
                  className={cn("w-2 h-2 rounded-full shrink-0", LEVEL_DOT[skill.skill_level])}
                />
                {skill.skill_name}
              </Badge>
            ))}
          </div>
        </section>
      )}

      {/* Quick stats — 4 key values */}
      {stats && (
        <section aria-label="Key stats">
          <h2 className="text-sm font-medium text-muted-foreground uppercase tracking-wide mb-3">
            Stats
          </h2>
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: "Tests Attempted", value: stats.tests_attempted },
              { label: "Tests Passed",    value: stats.tests_passed },
              {
                label: "Streak",
                value: `${stats.current_streak_days} ${stats.current_streak_days === 1 ? "day" : "days"}`,
              },
              {
                label: "Learning Hours",
                value: `${stats.learning_hours.toFixed(1)} hrs`,
              },
            ].map(({ label, value }) => (
              <div className="bg-muted rounded-lg p-3" key={label}>
                <p className="text-lg font-bold text-foreground">{value}</p>
                <p className="text-xs text-muted-foreground">{label}</p>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Social Links */}
      {social_links &&
        (social_links.linkedin || social_links.github || social_links.portfolio) && (
          <section aria-label="Social links">
            <h2 className="text-sm font-medium text-muted-foreground uppercase tracking-wide mb-3">
              Links
            </h2>
            <div className="flex flex-wrap gap-3">
              {social_links.linkedin && (
                <Link
                  aria-label="LinkedIn profile"
                  className="flex items-center gap-1.5 text-sm text-primary hover:underline"
                  href={social_links.linkedin}
                  rel="noopener noreferrer"
                  target="_blank"
                >
                  <Link2 aria-hidden="true" size={16} />
                  LinkedIn
                </Link>
              )}
              {social_links.github && (
                <Link
                  aria-label="GitHub profile"
                  className="flex items-center gap-1.5 text-sm text-primary hover:underline"
                  href={social_links.github}
                  rel="noopener noreferrer"
                  target="_blank"
                >
                  <ExternalLink aria-hidden="true" size={16} />
                  GitHub
                </Link>
              )}
              {social_links.portfolio && (
                <Link
                  aria-label="Portfolio website"
                  className="flex items-center gap-1.5 text-sm text-primary hover:underline"
                  href={social_links.portfolio}
                  rel="noopener noreferrer"
                  target="_blank"
                >
                  <Globe aria-hidden="true" size={16} />
                  Portfolio
                </Link>
              )}
            </div>
          </section>
        )}

      {/* Share */}
      <section aria-label="Share profile">
        <h2 className="text-sm font-medium text-muted-foreground uppercase tracking-wide mb-3">
          Share this profile
        </h2>
        <CopyButton url={profileUrl} />
      </section>
    </article>
  )
}
