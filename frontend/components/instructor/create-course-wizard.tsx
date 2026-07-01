"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { toast } from "sonner";
import { InfoTab }      from "@/components/instructor/wizard/info-tab";
import { StructureTab } from "@/components/instructor/wizard/structure-tab";
import { ContentTab }   from "@/components/instructor/wizard/content-tab";
import { SettingsTab }  from "@/components/instructor/wizard/settings-tab";
import { useCourseDraft, type WizardTab } from "@/lib/courses/use-course-draft";
import {
  createCourseAction, createSectionAction,
  createModuleAction, uploadAssetAction,
} from "@/lib/courses/actions";
import type { ContentBlock } from "@/lib/courses/draft-types";
import ROUTES from "@/lib/routes";

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function resolveBlockFiles(
  blocks: ContentBlock[],
  pendingFiles: Map<string, File>,
): Promise<ContentBlock[]> {
  return Promise.all(
    blocks.map(async (block) => {
      const file = pendingFiles.get(block.id);
      if (!file) return block;
      const fd = new FormData();
      fd.append("file", file);
      fd.append("type", block.type);
      const res = await uploadAssetAction(fd);
      if (!res.ok || !res.data) throw new Error(res.error ?? "File upload failed");
      pendingFiles.delete(block.id);
      return { ...block, url: res.data.url, previewUrl: undefined } as ContentBlock;
    }),
  );
}

// ─── Tab bar ─────────────────────────────────────────────────────────────────

const TABS: { id: WizardTab; label: string }[] = [
  { id: "info",      label: "Info"      },
  { id: "structure", label: "Structure" },
  { id: "content",   label: "Content"   },
  { id: "settings",  label: "Settings"  },
];

// ─── Wizard ───────────────────────────────────────────────────────────────────

export function CreateCourseWizard() {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const wiz = useCourseDraft();

  async function handleSubmit() {
    if (!wiz.draft.info.title.trim()) {
      wiz.setActiveTab("info");
      toast.error("Course title is required.");
      return;
    }

    startTransition(async () => {
      try {
        // 1. Upload cover image if file was selected
        let coverUrl = wiz.draft.info.cover_url;
        if (wiz.coverFile.current) {
          const fd = new FormData();
          fd.append("file", wiz.coverFile.current);
          const res = await uploadAssetAction(fd);
          if (!res.ok || !res.data) throw new Error(res.error ?? "Cover upload failed");
          coverUrl = res.data.url;
        }

        // 2. Create course
        const courseRes = await createCourseAction({
          title:       wiz.draft.info.title.trim(),
          description: wiz.draft.info.description.trim() || undefined,
          cover_url:   coverUrl || undefined,
          difficulty:  wiz.draft.info.difficulty,
          tags:        wiz.draft.info.tags,
          is_free:     wiz.draft.info.is_free,
        });
        if (!courseRes.ok || !courseRes.data) throw new Error(courseRes.error ?? "Failed to create course");
        const courseId = courseRes.data.id;

        // 3. Create sections + modules in order
        for (let si = 0; si < wiz.draft.sections.length; si++) {
          const section = wiz.draft.sections[si];
          const secRes = await createSectionAction({ course_id: courseId, title: section.title, position: si });
          if (!secRes.ok || !secRes.data) throw new Error(secRes.error ?? "Failed to create section");
          const sectionId = secRes.data.id;

          for (const mod of section.modules) {
            const resolvedBlocks = await resolveBlockFiles(mod.blocks, wiz.pendingFiles.current);
            await createModuleAction({
              course_id:         courseId,
              section_id:        sectionId,
              title:             mod.title,
              type:              mod.type,
              content_body:      resolvedBlocks.length > 0 ? JSON.stringify(resolvedBlocks) : undefined,
              estimated_minutes: mod.estimated_minutes,
            });
          }
        }

        toast.success("Course created!");
        router.push(ROUTES.manageCourse(courseId));
      } catch (err) {
        toast.error(err instanceof Error ? err.message : "Something went wrong.");
      }
    });
  }

  const totalModules = wiz.draft.sections.reduce((n, s) => n + s.modules.length, 0);

  return (
    <div className="flex flex-col gap-6">
      {/* Tab bar */}
      <div className="flex gap-1 border-b border-border" role="tablist">
        {TABS.map((tab) => (
          <button
            key={tab.id}
            role="tab"
            type="button"
            aria-selected={wiz.activeTab === tab.id}
            onClick={() => wiz.setActiveTab(tab.id)}
            className={cn(
              "px-4 py-2.5 text-sm transition-colors border-b-2 -mb-px",
              wiz.activeTab === tab.id
                ? "border-primary text-primary font-medium"
                : "border-transparent text-muted-foreground hover:text-foreground",
            )}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab panels */}
      <div className="min-h-[480px]">
        {wiz.activeTab === "info" && (
          <InfoTab
            info={wiz.draft.info}
            coverFile={wiz.coverFile.current}
            onChange={wiz.setInfo}
            onCoverFile={wiz.setCoverFile}
          />
        )}
        {wiz.activeTab === "structure" && (
          <StructureTab
            sections={wiz.draft.sections}
            activeModuleId={wiz.activeModuleId}
            onAddSection={wiz.addSection}
            onUpdateSection={wiz.updateSection}
            onRemoveSection={wiz.removeSection}
            onMoveSectionUp={wiz.moveSectionUp}
            onMoveSectionDown={wiz.moveSectionDown}
            onAddModule={wiz.addModule}
            onUpdateModule={wiz.updateModule}
            onRemoveModule={wiz.removeModule}
            onSelectModule={(id) => { wiz.setActiveModuleId(id); wiz.setActiveTab("content"); }}
          />
        )}
        {wiz.activeTab === "content" && (
          <ContentTab
            sections={wiz.draft.sections}
            activeModuleId={wiz.activeModuleId}
            onSelectModule={wiz.setActiveModuleId}
            onBlocksChange={wiz.setBlocks}
            onFile={(blockId, file) => { wiz.pendingFiles.current.set(blockId, file); }}
          />
        )}
        {wiz.activeTab === "settings" && (
          <SettingsTab
            status={wiz.draft.status}
            onChange={wiz.setStatus}
          />
        )}
      </div>

      {/* Footer */}
      <div className="flex items-center justify-between border-t border-border pt-4">
        <p className="text-xs text-muted-foreground">
          {wiz.draft.sections.length} section{wiz.draft.sections.length !== 1 ? "s" : ""} · {totalModules} lesson{totalModules !== 1 ? "s" : ""}
        </p>
        <Button disabled={pending} onClick={handleSubmit}>
          {pending ? "Creating…" : "Create course"}
        </Button>
      </div>
    </div>
  );
}
