import Link from "next/link";
import { FolderPlus, ListPlus, Sparkles } from "lucide-react";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

export type CreateSheetType = "existing" | "combine" | "custom";

interface SheetTypeSelectorProps {
  activeType: CreateSheetType;
}

const OPTIONS: { value: CreateSheetType; label: string; description: string; icon: typeof FolderPlus }[] = [
  {
    value: "existing",
    label: "Start from existing",
    description: "Track a built-in list like Striver's A2Z or NeetCode 150.",
    icon: FolderPlus,
  },
  {
    value: "combine",
    label: "Combine sheets",
    description: "Merge two or more of your sheets into one, deduped by topic.",
    icon: ListPlus,
  },
  {
    value: "custom",
    label: "Create custom",
    description: "Start from a blank sheet and add your own problems.",
    icon: Sparkles,
  },
];

export function SheetTypeSelector({ activeType }: SheetTypeSelectorProps) {
  return (
    <div className="grid-responsive-2 lg:grid-cols-3" role="tablist">
      {OPTIONS.map((option) => {
        const isActive = option.value === activeType;
        const Icon = option.icon;
        return (
          <Link
            aria-selected={isActive}
            className={cn(
              "card-base flex flex-col gap-2 p-6 text-left transition-colors duration-fast",
              isActive ? "border-primary bg-primary/5" : "hover:border-primary/40",
            )}
            href={`${ROUTES.SHEETS_NEW}?type=${option.value}`}
            key={option.value}
            role="tab"
          >
            <Icon aria-hidden className={cn("h-5 w-5", isActive ? "text-primary" : "text-muted-foreground")} />
            <p className="text-sm font-semibold text-foreground">{option.label}</p>
            <p className="text-xs text-muted-foreground">{option.description}</p>
          </Link>
        );
      })}
    </div>
  );
}
