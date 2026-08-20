import { Skeleton } from "@/components/ui/skeleton";

// LabEnvironment is a full-viewport workspace (terminal/editor/instructions
// panes), not a list/form page — a single full-height block is the honest
// shape here rather than guessing at an internal pane layout that can vary
// per lab type.
export default function LabSessionLoading() {
  return (
    <div className="flex h-dvh flex-col gap-2 p-4">
      <Skeleton className="h-10 w-full shrink-0" />
      <Skeleton className="flex-1" />
    </div>
  );
}
