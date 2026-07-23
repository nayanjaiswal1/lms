import { CohortTreeNode } from "@/components/cohorts/cohort-tree-node";
import { UngroupedDropZone } from "@/components/cohorts/ungrouped-drop-zone";
import { BatchRow } from "@/app/(app)/cohort-groups/batch-row";
import type { CohortGroup, CohortGroupNode, FlatCohortOption } from "@/lib/server/cohorts";
import type { Batch, OrgMemberSummary } from "@/lib/server/batches";

interface CohortGroupTreeProps {
  roots: CohortGroupNode[];
  allGroups: CohortGroup[];
  mode: "manage" | "picker";
  selectedId?: string;
  onSelect?: (id: string) => void;
  batches?: Batch[];
  options?: FlatCohortOption[];
  orgMembers?: OrgMemberSummary[];
}

export function CohortGroupTree({ roots, allGroups, mode, selectedId, onSelect, batches = [], options = [], orgMembers = [] }: CohortGroupTreeProps) {
  if (mode === "picker" && roots.length === 0) {
    return <p className="text-sm text-muted-foreground">No groups yet.</p>;
  }

  const ungrouped = batches.filter((b) => !b.cohort_group_id);

  return (
    <div className="flex flex-col gap-0.5">
      {mode === "manage" && (
        <>
          <UngroupedDropZone />
          {ungrouped.map((b) => (
            <BatchRow batch={b} key={b.id} options={options} orgMembers={orgMembers} />
          ))}
        </>
      )}
      {roots.map((node) => (
        <CohortTreeNode
          allGroups={allGroups}
          batches={batches}
          depth={0}
          key={node.id}
          mode={mode}
          node={node}
          options={options}
          orgMembers={orgMembers}
          selectedId={selectedId}
          onSelect={onSelect}
        />
      ))}
    </div>
  );
}
