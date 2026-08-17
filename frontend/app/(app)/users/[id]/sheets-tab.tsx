import { ListChecks } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { UserSheetSummary } from "@/app/(app)/users/[id]/types";

function SheetRow({ sheet }: { sheet: UserSheetSummary }) {
  const pct = sheet.item_count > 0 ? Math.round((sheet.solved_count / sheet.item_count) * 100) : 0;
  return (
    <div className="flex items-center gap-3 py-3 border-b border-border last:border-0">
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2 min-w-0">
          <p className="text-sm font-medium text-foreground truncate">{sheet.name}</p>
          <Badge variant="outline">{sheet.role}</Badge>
        </div>
        <div className="mt-1.5 flex items-center gap-2 max-w-xs">
          <div className="progress-track flex-1">
            {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
            <div className="progress-fill progress-fill-success" style={{ "--progress": `${pct}%` } as React.CSSProperties} />
          </div>
          <span className="text-xs text-muted-foreground shrink-0">
            {sheet.solved_count}/{sheet.item_count}
          </span>
        </div>
      </div>
    </div>
  );
}

export function SheetsTab({ sheets }: { sheets: UserSheetSummary[] }) {
  if (sheets.length === 0) {
    return (
      <div className="empty-state">
        <ListChecks aria-hidden className="empty-state-icon" />
        <p>Not tracking any sheets.</p>
      </div>
    );
  }

  return (
    <div className="card-base p-6">
      {sheets.map((s) => (
        <SheetRow key={s.id} sheet={s} />
      ))}
    </div>
  );
}
