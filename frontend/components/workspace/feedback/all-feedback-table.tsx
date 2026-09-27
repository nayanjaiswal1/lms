import { ResponsiveTable } from "@/components/ui/responsive-table";
import type { PeerFeedbackRow } from "@/lib/workspace/types";

/** Owner/overseer only (D15) — individual ratings, never shown to managers. */
export function AllFeedbackTable({ rows }: { rows: PeerFeedbackRow[] }) {
  if (rows.length === 0) return <p className="text-sm text-muted-foreground">No ratings submitted yet.</p>;

  return (
    <ResponsiveTable>
      <table className="w-full text-sm">
        <thead>
          <tr className="whitespace-nowrap text-left text-xs text-muted-foreground">
            <th className="pb-2">From</th>
            <th className="pb-2">To</th>
            <th className="pb-2">Rating</th>
            <th className="pb-2">Comment</th>
            <th className="pb-2">Date</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr className="whitespace-nowrap border-t border-border" key={i}>
              <td className="py-2">{row.from_user.name}</td>
              <td className="py-2">{row.to_user.name}</td>
              <td className="py-2">{row.rating} / 5</td>
              <td className="max-w-xs whitespace-normal py-2 text-muted-foreground">{row.comment ?? "—"}</td>
              <td className="py-2 text-muted-foreground">{new Date(row.created_at).toLocaleDateString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </ResponsiveTable>
  );
}
