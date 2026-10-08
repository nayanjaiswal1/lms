import type { LucideIcon } from "lucide-react";

interface StatTileProps {
  icon: LucideIcon;
  label: string;
  value: string | number;
  highlight?: boolean;
}

export function StatTile({ icon: Icon, label, value, highlight }: StatTileProps) {
  return (
    <div className="card-base flex flex-col gap-1 p-5">
      <div className="flex items-center gap-2 text-sm text-muted-foreground">
        <Icon aria-hidden className="h-4 w-4" />
        {label}
      </div>
      <p className={highlight ? "text-2xl font-bold text-primary" : "text-2xl font-bold"}>{value}</p>
    </div>
  );
}
