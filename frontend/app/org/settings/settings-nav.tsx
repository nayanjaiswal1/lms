"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Users,
  Globe,
  Shield,
  ScrollText,
  Cpu,
} from "lucide-react";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

interface OrgNavItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string; "aria-hidden"?: boolean | "true" | "false" }>;
  exact?: boolean;
}

const ORG_SETTINGS_NAV: OrgNavItem[] = [
  { label: "Overview",       href: ROUTES.ORG_SETTINGS,         icon: LayoutDashboard, exact: true },
  { label: "Members",        href: ROUTES.ORG_SETTINGS_MEMBERS,  icon: Users },
  { label: "Domains",        href: ROUTES.ORG_SETTINGS_DOMAINS,  icon: Globe },
  { label: "Authentication", href: ROUTES.ORG_SETTINGS_AUTH,     icon: Shield },
  { label: "Audit Log",      href: ROUTES.ORG_SETTINGS_AUDIT,    icon: ScrollText },
  { label: "Jobs",           href: ROUTES.ORG_SETTINGS_JOBS,     icon: Cpu },
];

export function OrgSettingsMobileNav() {
  const pathname = usePathname();

  return (
    <div
      aria-label="Organisation settings navigation"
      className="flex gap-2 overflow-x-auto pb-2 mb-6 lg:hidden"
      role="navigation"
    >
      {ORG_SETTINGS_NAV.map((item) => {
        const isActive = item.exact
          ? pathname === item.href
          : pathname.startsWith(item.href);
        return (
          <Link
            aria-current={isActive ? "page" : undefined}
            className={cn(
              "flex-shrink-0 px-4 py-2 rounded-full text-sm font-medium transition-colors duration-[--duration-fast]",
              isActive
                ? "bg-primary text-primary-foreground"
                : "bg-muted text-muted-foreground hover:text-foreground",
            )}
            href={item.href}
            key={item.href}
          >
            {item.label}
          </Link>
        );
      })}
    </div>
  );
}

export function OrgSettingsDesktopNav() {
  const pathname = usePathname();

  return (
    <aside className="hidden lg:block w-full lg:w-[220px] flex-shrink-0">
      <nav aria-label="Organisation settings navigation">
        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wider px-3 mb-1">
          Organisation
        </p>
        {ORG_SETTINGS_NAV.map((item) => {
          const Icon = item.icon;
          const isActive = item.exact
            ? pathname === item.href
            : pathname.startsWith(item.href);
          return (
            <Link
              aria-current={isActive ? "page" : undefined}
              className={cn(
                "flex items-center gap-2.5 px-3 py-2 rounded-md text-sm font-medium transition-colors duration-[--duration-fast] border-l-2",
                isActive
                  ? "text-primary border-primary bg-primary/5"
                  : "text-muted-foreground border-transparent hover:text-foreground hover:bg-muted",
              )}
              href={item.href}
              key={item.href}
            >
              <Icon aria-hidden="true" className="h-4 w-4 flex-shrink-0" />
              {item.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
