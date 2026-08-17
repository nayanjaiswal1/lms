"use client";

import type { LucideIcon } from "lucide-react";
import { Eye, GraduationCap, Presentation, Shield, ShieldCheck, Users as UsersIcon } from "lucide-react";

// System role name → icon. Tenant-created custom roles fall back to Shield.
export const ROLE_ICONS: Record<string, LucideIcon> = {
  viewer: Eye,
  member: GraduationCap,
  instructor: Presentation,
  mentor: UsersIcon,
  tenant_admin: ShieldCheck,
};

export function roleIcon(name: string): LucideIcon {
  return ROLE_ICONS[name] ?? Shield;
}

interface Props {
  roleNames: string[];
}

// One circular avatar per role, overlapping like a member/reviewer stack —
// later roles paint over earlier ones via DOM order, no z-index needed.
export function RoleBadges({ roleNames }: Props) {
  if (roleNames.length === 0) {
    return null;
  }

  return (
    <div className="flex items-center -space-x-2.5" title={roleNames.join(", ")}>
      {roleNames.map((name) => {
        const Icon = roleIcon(name);
        return (
          <div
            className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-muted ring-2 ring-background"
            key={name}
          >
            <Icon aria-hidden className="h-3.5 w-3.5 text-muted-foreground" />
          </div>
        );
      })}
      <span className="sr-only">{roleNames.join(", ")}</span>
    </div>
  );
}
