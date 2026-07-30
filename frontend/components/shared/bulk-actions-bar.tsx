import { Button } from "@/components/ui/button";

export interface BulkAction {
  label: string;
  onClick: () => void;
  variant?: "outline" | "destructive";
  disabled?: boolean;
}

interface BulkActionsBarProps {
  count: number;
  actions: BulkAction[];
  onClear: () => void;
}

// Generalizes the selection summary bar already duplicated (with drifted
// markup) in invite-table.tsx and add-people-panel.tsx.
export function BulkActionsBar({ count, actions, onClear }: BulkActionsBarProps) {
  if (count === 0) return null;

  return (
    <div className="flex flex-wrap items-center gap-3 rounded-md border border-border bg-muted p-3">
      <span className="shrink-0 text-sm text-muted-foreground">{count} selected</span>
      {actions.map((action) => (
        <Button
          disabled={action.disabled}
          key={action.label}
          size="sm"
          variant={action.variant ?? "outline"}
          onClick={action.onClick}
        >
          {action.label}
        </Button>
      ))}
      <Button className="sm:ml-auto" size="sm" variant="ghost" onClick={onClear}>
        Clear
      </Button>
    </div>
  );
}
