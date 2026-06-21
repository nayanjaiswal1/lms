"use client"

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { SETTINGS_NAV } from '@/lib/nav'

/** Mobile: horizontal scrolling pill row — hidden on lg+ */
export function SettingsMobileNav() {
  const pathname = usePathname()

  return (
    <div
      aria-label="Settings navigation"
      className="flex gap-2 overflow-x-auto pb-2 mb-6 lg:hidden"
      role="navigation"
    >
      {SETTINGS_NAV.flatMap((group) =>
        group.items.map((item) => {
          const isActive = item.exact
            ? pathname === item.href
            : pathname.startsWith(item.href)
          return (
            <Link
              aria-current={isActive ? 'page' : undefined}
              className={cn(
                'flex-shrink-0 px-4 py-2 rounded-full text-sm font-medium transition-colors duration-[--duration-fast]',
                isActive
                  ? 'bg-primary text-primary-foreground'
                  : 'bg-muted text-muted-foreground hover:text-foreground'
              )}
              href={item.href}
              key={item.href}
            >
              {item.label}
            </Link>
          )
        })
      )}
    </div>
  )
}

/** Desktop: left sidebar — hidden below lg */
export function SettingsDesktopNav() {
  const pathname = usePathname()

  return (
    <aside className="hidden lg:block w-full lg:w-[220px] flex-shrink-0">
      <nav aria-label="Settings navigation">
        {SETTINGS_NAV.map((group) => (
          <div className="mb-4" key={group.label ?? 'group'}>
            {group.label && (
              <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wider px-3 mb-1">
                {group.label}
              </p>
            )}
            {group.items.map((item) => {
              const Icon = item.icon
              const isActive = item.exact
                ? pathname === item.href
                : pathname.startsWith(item.href)
              return (
                <Link
                  aria-current={isActive ? 'page' : undefined}
                  className={cn(
                    'flex items-center gap-2.5 px-3 py-2 rounded-md text-sm font-medium transition-colors duration-[--duration-fast] border-l-2',
                    isActive
                      ? 'text-primary border-primary bg-primary/5'
                      : 'text-muted-foreground border-transparent hover:text-foreground hover:bg-muted'
                  )}
                  href={item.href}
                  key={item.href}
                >
                  <Icon aria-hidden="true" className="h-4 w-4 flex-shrink-0" />
                  {item.label}
                </Link>
              )
            })}
          </div>
        ))}
      </nav>
    </aside>
  )
}
