import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { ITEM_STATUS_LABEL, ITEM_STATUS_VARIANT, ITEM_TYPE_LABEL } from "@/lib/workspace/items-constants";
import type { SimilarItem } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface DuplicateCheckPanelProps {
  workspaceId: string;
  similar: SimilarItem[];
  searching: boolean;
}

/** Purely presentational — create-item-dialog.tsx owns the debounced search
 * (wired into the title field's onChange, not a useEffect watcher, per
 * frontend/CLAUDE.md's "no fetch() in useEffect" rule) and passes results
 * down. "Link as duplicate instead" navigates to the existing item — it does
 * not create anything (04-frontend.md §7 "Duplicate check"). */
export function DuplicateCheckPanel({ workspaceId, similar, searching }: DuplicateCheckPanelProps) {
  if (!searching && similar.length === 0) return null;

  return (
    <div className="ai-surface flex flex-col gap-2 rounded-md p-3">
      <div className="flex items-center gap-2">
        <span className="ai-badge">Similar</span>
        <p className="text-sm font-medium">
          {searching ? "Checking for similar items…" : "These already look close"}
        </p>
      </div>
      {!searching && similar.length > 0 && (
        <ul className="flex flex-col gap-1.5">
          {similar.map((item) => (
            <li className="flex items-center justify-between gap-2 text-sm" key={item.id}>
              <span className="min-w-0 truncate">
                <span className="font-mono text-xs text-muted-foreground">{item.key}</span> {item.title}
              </span>
              <div className="flex shrink-0 items-center gap-1.5">
                <Badge variant="outline">{ITEM_TYPE_LABEL[item.type]}</Badge>
                <Badge variant={ITEM_STATUS_VARIANT[item.status]}>{ITEM_STATUS_LABEL[item.status]}</Badge>
                <Link className="text-xs text-primary hover:underline" href={ROUTES.workspaceItem(workspaceId, item.key)}>
                  Link as duplicate instead
                </Link>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
