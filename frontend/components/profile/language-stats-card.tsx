import type { LanguageCount } from '@/lib/profile/types'

interface Props {
  languages: LanguageCount[]
}

export function LanguageStatsCard({ languages }: Props) {
  if (languages.length === 0) return null

  return (
    <section aria-label="Languages" className="card-base p-6 space-y-3">
      <h2 className="text-sm font-semibold text-foreground">Languages</h2>
      <ul className="space-y-2">
        {languages.map((lang) => (
          <li className="flex items-center justify-between gap-3 text-sm" key={lang.language}>
            <span className="text-foreground">{lang.language}</span>
            <span className="text-muted-foreground tabular-nums">
              {lang.solved} {lang.solved === 1 ? 'problem' : 'problems'} solved
            </span>
          </li>
        ))}
      </ul>
    </section>
  )
}
