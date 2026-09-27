import { ResponsiveTable } from "@/components/ui/responsive-table";
import { PROJECT_ROLE_LABEL } from "@/lib/workspace/roles";
import type { PersonMetrics, TrackMetrics } from "@/lib/workspace/types";

interface TeamSectionProps {
  tracks: TrackMetrics[];
  people: PersonMetrics[];
}

// D15 visibility: `people` may already be narrowed (own track / own row) or
// empty (viewer) by the time it reaches this component — no client-side
// filtering happens here, the server already decided what this caller sees.
export function TeamSection({ tracks, people }: TeamSectionProps) {
  return (
    <div className="flex flex-col gap-4">
      {tracks.length > 0 && (
        <div className="card-base flex flex-col gap-3">
          <h2 className="section-title">Tracks</h2>
          <ResponsiveTable>
            <table className="w-full text-sm">
              <thead>
                <tr className="whitespace-nowrap text-left text-xs text-muted-foreground">
                  <th className="px-3 py-2">Track</th>
                  <th className="px-3 py-2">Lead</th>
                  <th className="px-3 py-2">Members</th>
                  <th className="px-3 py-2">Open</th>
                  <th className="px-3 py-2">Done</th>
                  <th className="px-3 py-2">WIP</th>
                  <th className="px-3 py-2">Bugs</th>
                  <th className="px-3 py-2">Awaiting doc</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {tracks.map((t) => (
                  <tr className="whitespace-nowrap" key={t.track_id}>
                    <td className="px-3 py-2 font-medium">{t.name}</td>
                    <td className="px-3 py-2 text-muted-foreground">{t.lead?.name ?? "No lead"}</td>
                    <td className="px-3 py-2">{t.members}</td>
                    <td className="px-3 py-2">{t.open}</td>
                    <td className="px-3 py-2">{t.done}</td>
                    <td className="px-3 py-2">{t.wip}</td>
                    <td className="px-3 py-2">{t.bugs}</td>
                    <td className="px-3 py-2">{t.features_awaiting_doc}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </ResponsiveTable>
        </div>
      )}

      {people.length > 0 && (
        <div className="card-base flex flex-col gap-3">
          <h2 className="section-title">People</h2>
          <p className="text-xs text-muted-foreground">Coaching signal, not a ranking — this table is never sorted by a score.</p>
          <ResponsiveTable>
            <table className="w-full text-sm">
              <thead>
                <tr className="whitespace-nowrap text-left text-xs text-muted-foreground">
                  <th className="px-3 py-2">Person</th>
                  <th className="px-3 py-2">Role</th>
                  <th className="px-3 py-2">WIP</th>
                  <th className="px-3 py-2">Completed</th>
                  <th className="px-3 py-2">Reviews</th>
                  <th className="px-3 py-2">Time logged</th>
                  <th className="px-3 py-2">Onboarding</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {people.map((p) => (
                  <tr className="whitespace-nowrap" key={p.person.user_id}>
                    <td className="px-3 py-2 font-medium">{p.person.name}</td>
                    <td className="px-3 py-2 text-muted-foreground">{PROJECT_ROLE_LABEL[p.role]}</td>
                    <td className="px-3 py-2">{p.wip} / {p.wip_limit}</td>
                    <td className="px-3 py-2">{p.completed_owned}</td>
                    <td className="px-3 py-2">{p.reviews_done}</td>
                    <td className="px-3 py-2">{(p.minutes_logged / 60).toFixed(1)}h</td>
                    <td className="px-3 py-2">{p.onboarding_pct}%</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </ResponsiveTable>
        </div>
      )}
    </div>
  );
}
