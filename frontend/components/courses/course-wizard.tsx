"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { toast } from "sonner";
import { InfoTab }      from "@/components/courses/wizard/info-tab";
import { StructureTab } from "@/components/courses/wizard/structure-tab";
import { ContentTab }   from "@/components/courses/wizard/content-tab";
import { SettingsTab }  from "@/components/courses/wizard/settings-tab";
import { FinalTestTab } from "@/components/courses/wizard/final-test-tab";
import { useCourseDraft, type WizardTab } from "@/lib/courses/use-course-draft";
import type { CertificateRule, FinalTestConfig } from "@/lib/server/courses";
import {
  createCourseAction, updateCourseAction, publishCourseAction,
  createSectionAction, updateSectionAction, deleteSectionAction, reorderSectionsAction,
  createModuleAction, updateModuleAction, deleteModuleAction, reorderModulesAction,
  uploadAssetAction,
} from "@/lib/courses/actions";
import { parseBlocks, type ContentBlock } from "@/lib/courses/draft-types";
import type { CourseTree } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface Props {
  course?: CourseTree; // present in edit mode, absent when creating a new course
  finalTest?: FinalTestConfig | null; // present only in edit mode
  certificateRule?: CertificateRule | null; // present only in edit mode
}

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
  { id: "final-test", label: "Final Test" },
];

// ─── Wizard ───────────────────────────────────────────────────────────────────

export function CourseWizard({ course, finalTest, certificateRule }: Props) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const wiz = useCourseDraft(course);

  async function handleSubmit() {
    if (!wiz.draft.info.title.trim()) {
      wiz.setActiveTab("info");
      toast.error("Course title is required.");
      return;
    }

    startTransition(async () => {
      try {
        // 1. Upload cover image if a new file was selected
        let coverUrl = wiz.draft.info.cover_url;
        if (wiz.coverFile.current) {
          const fd = new FormData();
          fd.append("file", wiz.coverFile.current);
          const res = await uploadAssetAction(fd);
          if (!res.ok || !res.data) throw new Error(res.error ?? "Cover upload failed");
          coverUrl = res.data.url;
        }

        const slug = course
          ? await saveExistingCourse(course, coverUrl)
          : await createNewCourse(coverUrl);

        toast.success(course ? "Course updated!" : "Course created!");
        router.push(ROUTES.courseEdit(slug));
      } catch (err) {
        toast.error(err instanceof Error ? err.message : "Something went wrong.");
      }
    });
  }

  async function createNewCourse(coverUrl: string): Promise<string> {
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
    const slug = courseRes.data.slug;

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

    if (wiz.draft.status === "published") {
      const pubRes = await publishCourseAction(courseId);
      if (!pubRes.ok) throw new Error(pubRes.error ?? "Course was created but failed to publish.");
    }

    return slug;
  }

  async function saveExistingCourse(existing: CourseTree, coverUrl: string): Promise<string> {
    const courseId = existing.id;

    const updateRes = await updateCourseAction(courseId, existing.slug, {
      title:       wiz.draft.info.title.trim(),
      description: wiz.draft.info.description.trim() || undefined,
      cover_url:   coverUrl || undefined,
      difficulty:  wiz.draft.info.difficulty,
      tags:        wiz.draft.info.tags,
      is_free:     wiz.draft.info.is_free,
    });
    if (!updateRes.ok) throw new Error(updateRes.error ?? "Failed to save changes.");

    if (wiz.draft.status === "published" && existing.status !== "published") {
      const pubRes = await publishCourseAction(courseId);
      if (!pubRes.ok) throw new Error(pubRes.error ?? "Failed to publish course.");
    }

    // Deletions are best-effort: a module whose parent section was also
    // removed is already gone via cascade, so a redundant delete 404s harmlessly.
    for (const sectionId of wiz.removedSectionIds.current) {
      await deleteSectionAction(sectionId);
    }
    for (const moduleId of wiz.removedModuleIds.current) {
      await deleteModuleAction(moduleId);
    }

    // Diff against the tree the wizard was loaded with — only write what the
    // user actually touched, instead of resending every section/module on
    // every save.
    const originalSections = new Map(existing.sections.map((s) => [s.id, s]));
    const originalModules = new Map(existing.sections.flatMap((s) => s.modules.map((m) => [m.id, m])));

    const finalSectionIds: string[] = [];
    for (let si = 0; si < wiz.draft.sections.length; si++) {
      const section = wiz.draft.sections[si];
      let sectionId = section.id;
      if (sectionId) {
        const original = originalSections.get(sectionId);
        if (!original || original.title !== section.title) {
          const res = await updateSectionAction(sectionId, { title: section.title });
          if (!res.ok) throw new Error(res.error ?? "Failed to update section.");
        }
      } else {
        const res = await createSectionAction({ course_id: courseId, title: section.title, position: si });
        if (!res.ok || !res.data) throw new Error(res.error ?? "Failed to create section.");
        sectionId = res.data.id;
      }
      finalSectionIds.push(sectionId);

      const finalModuleIds: string[] = [];
      for (const mod of section.modules) {
        if (mod.id) {
          const original = originalModules.get(mod.id);
          const resolvedBlocks = await resolveBlockFiles(mod.blocks, wiz.pendingFiles.current);
          const content_body = resolvedBlocks.length > 0 ? JSON.stringify(resolvedBlocks) : undefined;
          const normalizedOriginalBody = original?.content_body
            ? JSON.stringify(parseBlocks(original.content_body))
            : undefined;
          const unchanged =
            original !== undefined &&
            mod.title === original.title &&
            mod.type === original.type &&
            (mod.estimated_minutes ?? null) === (original.estimated_minutes ?? null) &&
            mod.is_free_preview === original.is_free_preview &&
            content_body === normalizedOriginalBody;

          if (!unchanged) {
            const res = await updateModuleAction(mod.id, {
              title:              mod.title,
              type:               mod.type,
              content_body,
              estimated_minutes:  mod.estimated_minutes,
              is_free_preview:    mod.is_free_preview,
            });
            if (!res.ok) throw new Error(res.error ?? "Failed to update lesson.");
          }
          finalModuleIds.push(mod.id);
        } else {
          const resolvedBlocks = await resolveBlockFiles(mod.blocks, wiz.pendingFiles.current);
          const content_body = resolvedBlocks.length > 0 ? JSON.stringify(resolvedBlocks) : undefined;
          const res = await createModuleAction({
            course_id:         courseId,
            section_id:        sectionId,
            title:             mod.title,
            type:              mod.type,
            content_body,
            estimated_minutes: mod.estimated_minutes,
          });
          if (!res.ok || !res.data) throw new Error(res.error ?? "Failed to create lesson.");
          finalModuleIds.push(res.data.id);
        }
      }

      const originalModuleIds = originalSections.get(section.id ?? "")?.modules.map((m) => m.id) ?? [];
      if (JSON.stringify(finalModuleIds) !== JSON.stringify(originalModuleIds)) {
        const reorderRes = await reorderModulesAction(sectionId, finalModuleIds);
        if (!reorderRes.ok) throw new Error(reorderRes.error ?? "Failed to save lesson order.");
      }
    }

    const originalSectionIds = existing.sections.map((s) => s.id);
    if (JSON.stringify(finalSectionIds) !== JSON.stringify(originalSectionIds)) {
      const reorderRes = await reorderSectionsAction(courseId, finalSectionIds);
      if (!reorderRes.ok) throw new Error(reorderRes.error ?? "Failed to save section order.");
    }

    return existing.slug;
  }

  const totalModules = wiz.draft.sections.reduce((n, s) => n + s.modules.length, 0);

  return (
    <div className="flex flex-col gap-6">
      {/* Tab bar */}
      <div className="flex gap-1 border-b border-border" role="tablist">
        {TABS.filter((tab) => tab.id !== "final-test" || course).map((tab) => (
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
            disableDraft={course?.status === "published"}
          />
        )}
        {wiz.activeTab === "final-test" && course && (
          <FinalTestTab courseId={course.id} initial={finalTest ?? null} certificateRule={certificateRule ?? null} />
        )}
      </div>

      {/* Footer */}
      <div className="flex items-center justify-between border-t border-border pt-4">
        <p className="text-xs text-muted-foreground">
          {wiz.draft.sections.length} section{wiz.draft.sections.length !== 1 ? "s" : ""} · {totalModules} lesson{totalModules !== 1 ? "s" : ""}
        </p>
        <Button disabled={pending} onClick={handleSubmit}>
          {pending
            ? (course ? "Saving…" : "Creating…")
            : (course ? "Save changes" : "Create course")}
        </Button>
      </div>
    </div>
  );
}
