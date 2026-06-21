"use client";

import Link from "next/link";
import { useTransition } from "react";
import { ChevronsUpDown, LogOut, Settings } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ProfileAvatar } from "@/components/profile/profile-avatar";
import { logoutAction } from "@/app/actions/logout-action";
import type { AuthUser } from "@/lib/server/auth";
import ROUTES from "@/lib/routes";

interface Props {
  user: AuthUser;
}

export function SidebarUserMenu({ user }: Props) {
  const [pending, startTransition] = useTransition();

  return (
    <div className="border-t border-sidebar-border p-3">
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <button
            aria-label="User menu"
            className="flex w-full items-center gap-3 rounded-md px-2 py-2 text-sm hover:bg-accent/60 transition-colors duration-fast touch-target"
          >
            <ProfileAvatar avatarUrl={user.avatar_url} name={user.name} size="sm" />
            <div className="flex min-w-0 flex-1 flex-col items-start">
              <span className="w-full truncate text-sm font-medium text-foreground">
                {user.name}
              </span>
              <span className="w-full truncate text-xs text-muted-foreground">
                {user.email}
              </span>
            </div>
            <ChevronsUpDown aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-56" side="top" sideOffset={8}>
          <DropdownMenuLabel className="font-normal">
            <div className="flex flex-col gap-0.5">
              <span className="text-sm font-medium text-foreground">{user.name}</span>
              <span className="text-xs text-muted-foreground">{user.email}</span>
            </div>
          </DropdownMenuLabel>
          <DropdownMenuSeparator />
          <DropdownMenuItem asChild>
            <Link className="flex items-center gap-2" href={ROUTES.SETTINGS_PROFILE}>
              <Settings aria-hidden className="h-4 w-4" />
              Profile settings
            </Link>
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem
            className="text-destructive focus:text-destructive"
            disabled={pending}
            onSelect={() => startTransition(() => logoutAction())}
          >
            <LogOut aria-hidden className="h-4 w-4" />
            {pending ? "Signing out…" : "Sign out"}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
