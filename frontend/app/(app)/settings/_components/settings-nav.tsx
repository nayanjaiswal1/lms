"use client"

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { SETTINGS_NAV, type NavGroup } from '@/lib/nav'

type SettingsNavItem = NavGroup['items'][number]

const NAV_ITEMS = SETTINGS_NAV.flatMap((group) => group.items)

// A nav with a single destination is pure chrome — both variants hide it.
const HAS_NAV = NAV_ITEMS.length > 1

function isActiveItem(item: SettingsNavItem, pathname: string): boolean {
  return item.exact ? pathname === item.href : pathname.startsWith(item.href)
}

/** Mobile: scrollable segmented control — hidden on lg+ */
export function SettingsMobileNav() {
  const pathname = usePathname()
  if (!HAS_NAV) return null

  return (
    <nav aria-label="Settings sections" className="mb-6 lg:hidden">
      <div className="flex gap-1 overflow-x-auto rounded-lg bg-muted p-1">
        {NAV_ITEMS.map((item) => {
          const Icon = item.icon
          const isActive = isActiveItem(item, pathname)
          return (
            <Link
              aria-current={isActive ? 'page' : undefined}
              className={cn(
                'flex min-h-11 flex-1 shrink-0 items-center justify-center gap-2 whitespace-nowrap rounded-md px-4 text-sm font-medium',
                'transition-colors duration-fast ease-smooth',
                'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
                isActive
                  ? 'bg-background text-foreground shadow-sm'
                  : 'text-muted-foreground hover:text-foreground'
              )}
              href={item.href}
              key={item.href}
            >
              <Icon aria-hidden="true" className={cn('h-4 w-4 shrink-0', isActive && 'text-primary')} />
              {item.label}
            </Link>
          )
        })}
      </div>
    </nav>
  )
}

/** Desktop: sticky left sidebar — hidden below lg */
export function SettingsDesktopNav() {
  const pathname = usePathname()
  if (!HAS_NAV) return null

  return (
    <aside className="hidden w-full shrink-0 lg:sticky lg:top-20 lg:block lg:w-52">
      <nav aria-label="Settings sections" className="space-y-6">
        {SETTINGS_NAV.map((group) => (
          <div className="space-y-1" key={group.label ?? 'group'}>
            {group.label && (
              <p className="px-3 pb-1 text-xs font-medium text-muted-foreground">{group.label}</p>
            )}
            {group.items.map((item) => {
              const Icon = item.icon
              const isActive = isActiveItem(item, pathname)
              return (
                <Link
                  aria-current={isActive ? 'page' : undefined}
                  className={cn(
                    'relative flex min-h-10 items-center gap-3 rounded-md px-3 text-sm font-medium',
                    'transition-colors duration-fast ease-smooth',
                    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
                    isActive
                      ? 'bg-primary/10 text-primary before:absolute before:inset-y-2 before:left-0 before:w-0.5 before:rounded-full before:bg-primary'
                      : 'text-muted-foreground hover:bg-muted hover:text-foreground'
                  )}
                  href={item.href}
                  key={item.href}
                >
                  <Icon aria-hidden="true" className="h-4 w-4 shrink-0" />
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
