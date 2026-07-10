'use client'

import { parseAsStringLiteral, useQueryState } from 'nuqs'
import { History, ListChecks } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'
import type { RecentActivityItem } from '@/lib/profile/types'

interface Props {
  items: RecentActivityItem[]
}

const ACTIVITY_TABS = ['recent', 'all'] as const
const TAB_ICON: Record<(typeof ACTIVITY_TABS)[number], typeof History> = {
  recent: History,
  all:    ListChecks,
}
const TAB_LABEL: Record<(typeof ACTIVITY_TABS)[number], string> = {
  recent: 'Recent AC',
  all:    'All',
}

const RECENT_STATUSES = new Set(['submitted', 'evaluated'])

function relativeTime(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime()
  const mins = Math.floor(diffMs / 60_000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins} min${mins === 1 ? '' : 's'} ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours} hour${hours === 1 ? '' : 's'} ago`
  const days = Math.floor(hours / 24)
  if (days < 30) return `${days} day${days === 1 ? '' : 's'} ago`
  const months = Math.floor(days / 30)
  if (months < 12) return `${months} month${months === 1 ? '' : 's'} ago`
  const years = Math.floor(months / 12)
  return `${years} year${years === 1 ? '' : 's'} ago`
}

export function RecentSubmissionsList({ items }: Props) {
  const [activity, setActivity] = useQueryState(
    'activity',
    parseAsStringLiteral(ACTIVITY_TABS).withDefault('recent'),
  )

  const filtered = activity === 'recent'
    ? items.filter((item) => RECENT_STATUSES.has(item.status))
    : items

  return (
    <section aria-label="Recent activity" className="card-base p-6">
      <div
        aria-label="Activity filter"
        className="flex gap-1 border-b border-border -mt-1 mb-4"
        role="tablist"
      >
        {ACTIVITY_TABS.map((tab) => {
          const isActive = tab === activity
          const Icon = TAB_ICON[tab]
          return (
            <button
              aria-selected={isActive}
              className={cn(
                'flex items-center gap-1.5 px-3 py-2 text-sm font-medium border-b-2 transition-colors duration-fast',
                isActive
                  ? 'text-primary border-primary'
                  : 'text-muted-foreground border-transparent hover:text-foreground hover:border-border',
              )}
              key={tab}
              role="tab"
              type="button"
              onClick={() => void setActivity(tab)}
            >
              <Icon aria-hidden="true" size={14} />
              {TAB_LABEL[tab]}
            </button>
          )
        })}
      </div>

      {filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground py-6 text-center">
          No activity yet. Attempt a question to see it show up here.
        </p>
      ) : (
        <ul>
          {filtered.map((item, index) => (
            <li
              className={cn(
                'flex items-center justify-between gap-3 px-3 py-3 rounded-md',
                index % 2 === 1 && 'bg-muted/40',
              )}
              key={item.attempt_id}
            >
              <div className="min-w-0">
                <p className="text-sm font-medium text-foreground truncate">{item.assessment_title}</p>
                <p className="text-xs text-muted-foreground">{relativeTime(item.occurred_at)}</p>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                {item.percentage !== null && (
                  <span className="text-xs text-muted-foreground tabular-nums">
                    {item.percentage.toFixed(0)}%
                  </span>
                )}
                {item.passed !== null && (
                  <Badge variant={item.passed ? 'default' : 'destructive'}>
                    {item.passed ? 'Passed' : 'Failed'}
                  </Badge>
                )}
                {item.passed === null && (
                  <Badge variant="secondary">{item.status.replace('_', ' ')}</Badge>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
