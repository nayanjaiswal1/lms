import { Badge } from '@/components/ui/badge'
import type { MyBatch } from '@/lib/server/batches'

interface Props {
  batches: MyBatch[]
}

export function BatchesSummaryCard({ batches }: Props) {
  return (
    <section aria-label="Batches joined" className="card-base p-6 flex-1">
      <h2 className="text-sm font-semibold text-foreground mb-2">Batches</h2>
      <p className="text-2xl font-bold text-foreground tabular-nums">{batches.length}</p>
      <p className="text-xs text-muted-foreground">
        {batches.length === 1 ? 'batch' : 'batches'} joined
      </p>

      {batches.length > 0 && (
        <ul className="flex flex-wrap gap-1.5 pt-2 mt-2 border-t border-border">
          {batches.map((batch) => (
            <li key={batch.id}>
              <Badge variant="secondary">{batch.name}</Badge>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
