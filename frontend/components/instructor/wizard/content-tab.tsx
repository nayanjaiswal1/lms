"use client";

import { cn } from "@/lib/utils";
import { BlockEditor } from "@/components/instructor/block-editor";
import type { DraftSection, ContentBlock } from "@/lib/courses/draft-types";

interface ContentTabProps {
  sections:        DraftSection[];
  activeModuleId:  string | null;
  onSelectModule:  (id: string) => void;
  onBlocksChange:  (sectionLocalId: string, moduleLocalId: string, blocks: ContentBlock[]) => void;
  onFile:          (blockId: string, file: File) => void;
}

export function ContentTab({
  sections, activeModuleId, onSelectModule, onBlocksChange, onFile,
}: ContentTabProps) {
  let activeSection: DraftSection | null = null;
  let activeBlocks: ContentBlock[] = [];

  for (const section of sections) {
    const mod = section.modules.find((m) => m.localId === activeModuleId);
    if (mod) {
      activeSection = section;
      activeBlocks = mod.blocks;
      break;
    }
  }

  const totalModules = sections.reduce((n, s) => n + s.modules.length, 0);

  return (
    <div className="flex gap-6 min-h-[500px]">
      {/* Left: module list */}
      <aside className="w-56 shrink-0 flex flex-col gap-3">
        <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">Lessons</p>
        {totalModules === 0 ? (
          <p className="text-xs text-muted-foreground">Add lessons in the Structure tab first.</p>
        ) : (
          sections.map((section) =>
            section.modules.length === 0 ? null : (
              <div key={section.localId} className="flex flex-col gap-0.5">
                <p className="px-2 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground truncate">
                  {section.title || "Untitled section"}
                </p>
                {section.modules.map((mod) => (
                  <button
                    key={mod.localId}
                    type="button"
                    onClick={() => onSelectModule(mod.localId)}
                    className={cn(
                      "flex items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm transition-colors",
                      mod.localId === activeModuleId
                        ? "bg-primary/10 text-primary font-medium"
                        : "text-foreground hover:bg-muted",
                    )}
                  >
                    <span className="line-clamp-1">{mod.title || "Untitled lesson"}</span>
                    {mod.blocks.length > 0 && (
                      <span className="ml-auto shrink-0 text-[10px] text-muted-foreground">
                        {mod.blocks.length}
                      </span>
                    )}
                  </button>
                ))}
              </div>
            ),
          )
        )}
      </aside>

      {/* Right: block editor */}
      <div className="flex-1 min-w-0">
        {!activeModuleId || !activeSection ? (
          <div className="flex h-full items-center justify-center text-center">
            <div className="flex flex-col gap-2">
              <p className="text-sm font-medium">Select a lesson to edit its content</p>
              <p className="text-xs text-muted-foreground">
                {totalModules === 0
                  ? "Add sections and lessons in the Structure tab first."
                  : "Click a lesson from the list on the left."}
              </p>
            </div>
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            {(() => {
              const mod = activeSection.modules.find((m) => m.localId === activeModuleId)!;
              return (
                <>
                  <div className="flex items-center justify-between border-b border-border pb-3">
                    <div>
                      <p className="font-medium">{mod.title || "Untitled lesson"}</p>
                      <p className="text-xs text-muted-foreground capitalize">
                        {mod.type} · {mod.estimated_minutes} min
                      </p>
                    </div>
                  </div>
                  <BlockEditor
                    blocks={activeBlocks}
                    onChange={(blocks) => onBlocksChange(activeSection!.localId, activeModuleId, blocks)}
                    onFile={onFile}
                  />
                </>
              );
            })()}
          </div>
        )}
      </div>
    </div>
  );
}
