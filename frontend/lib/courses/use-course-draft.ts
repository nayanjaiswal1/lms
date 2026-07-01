"use client";

import { useState, useRef, useCallback } from "react";
import {
  type CourseDraft, type DraftSection, type DraftModule, type ContentBlock,
  EMPTY_DRAFT, makeSection, makeModule, makeBlock,
} from "@/lib/courses/draft-types";

export type WizardTab = "info" | "structure" | "content" | "settings";

interface WizardState {
  draft:           CourseDraft;
  activeTab:       WizardTab;
  activeModuleId:  string | null;
  submitting:      boolean;
  error:           string | null;
}

export function useCourseDraft() {
  const [state, setState] = useState<WizardState>({
    draft:          EMPTY_DRAFT,
    activeTab:      "info",
    activeModuleId: null,
    submitting:     false,
    error:          null,
  });

  // File references — not in React state (File objects are not serializable)
  const pendingFiles = useRef<Map<string, File>>(new Map());
  const coverFile    = useRef<File | null>(null);

  const patch = useCallback((partial: Partial<WizardState>) =>
    setState((s) => ({ ...s, ...partial })), []);

  // ── Info ──────────────────────────────────────────────────────────────────

  const setInfo = useCallback(
    (info: Partial<CourseDraft["info"]>) =>
      setState((s) => ({ ...s, draft: { ...s.draft, info: { ...s.draft.info, ...info } } })),
    [],
  );

  const setCoverFile = useCallback((file: File | null) => {
    coverFile.current = file;
    setState((s) => ({
      ...s,
      draft: { ...s.draft, info: { ...s.draft.info, cover_url: file ? URL.createObjectURL(file) : "" } },
    }));
  }, []);

  // ── Sections ──────────────────────────────────────────────────────────────

  const addSection = useCallback(() =>
    setState((s) => ({ ...s, draft: { ...s.draft, sections: [...s.draft.sections, makeSection()] } })), []);

  const updateSection = useCallback((localId: string, title: string) =>
    setState((s) => ({
      ...s,
      draft: { ...s.draft, sections: s.draft.sections.map((sec) => sec.localId === localId ? { ...sec, title } : sec) },
    })), []);

  const removeSection = useCallback((localId: string) =>
    setState((s) => ({
      ...s,
      draft: { ...s.draft, sections: s.draft.sections.filter((sec) => sec.localId !== localId) },
      activeModuleId: null,
    })), []);

  const moveSectionUp = useCallback((index: number) =>
    setState((s) => {
      if (index === 0) return s;
      const secs = [...s.draft.sections];
      [secs[index - 1], secs[index]] = [secs[index], secs[index - 1]];
      return { ...s, draft: { ...s.draft, sections: secs } };
    }), []);

  const moveSectionDown = useCallback((index: number) =>
    setState((s) => {
      if (index >= s.draft.sections.length - 1) return s;
      const secs = [...s.draft.sections];
      [secs[index], secs[index + 1]] = [secs[index + 1], secs[index]];
      return { ...s, draft: { ...s.draft, sections: secs } };
    }), []);

  // ── Modules ───────────────────────────────────────────────────────────────

  const addModule = useCallback((sectionLocalId: string, type = "notes") =>
    setState((s) => ({
      ...s,
      draft: {
        ...s.draft,
        sections: s.draft.sections.map((sec) =>
          sec.localId === sectionLocalId ? { ...sec, modules: [...sec.modules, makeModule(type)] } : sec,
        ),
      },
    })), []);

  const updateModule = useCallback((sectionLocalId: string, moduleLocalId: string, patch: Partial<DraftModule>) =>
    setState((s) => ({
      ...s,
      draft: {
        ...s.draft,
        sections: s.draft.sections.map((sec) =>
          sec.localId !== sectionLocalId ? sec : {
            ...sec,
            modules: sec.modules.map((mod) => mod.localId === moduleLocalId ? { ...mod, ...patch } : mod),
          },
        ),
      },
    })), []);

  const removeModule = useCallback((sectionLocalId: string, moduleLocalId: string) =>
    setState((s) => ({
      ...s,
      activeModuleId: s.activeModuleId === moduleLocalId ? null : s.activeModuleId,
      draft: {
        ...s.draft,
        sections: s.draft.sections.map((sec) =>
          sec.localId !== sectionLocalId ? sec : { ...sec, modules: sec.modules.filter((m) => m.localId !== moduleLocalId) },
        ),
      },
    })), []);

  // ── Blocks ────────────────────────────────────────────────────────────────

  const setBlocks = useCallback(
    (sectionLocalId: string, moduleLocalId: string, blocks: ContentBlock[]) =>
      setState((s) => ({
        ...s,
        draft: {
          ...s.draft,
          sections: s.draft.sections.map((sec) =>
            sec.localId !== sectionLocalId ? sec : {
              ...sec,
              modules: sec.modules.map((mod) => mod.localId === moduleLocalId ? { ...mod, blocks } : mod),
            },
          ),
        },
      })),
    [],
  );

  const addBlock = useCallback(
    (sectionLocalId: string, moduleLocalId: string, type: ContentBlock["type"]) =>
      setState((s) => {
        const block = makeBlock(type);
        return {
          ...s,
          draft: {
            ...s.draft,
            sections: s.draft.sections.map((sec) =>
              sec.localId !== sectionLocalId ? sec : {
                ...sec,
                modules: sec.modules.map((mod) =>
                  mod.localId === moduleLocalId ? { ...mod, blocks: [...mod.blocks, block] } : mod,
                ),
              },
            ),
          },
        };
      }),
    [],
  );

  const setStatus = useCallback(
    (status: CourseDraft["status"]) =>
      setState((s) => ({ ...s, draft: { ...s.draft, status } })),
    [],
  );

  return {
    draft:         state.draft,
    activeTab:     state.activeTab,
    activeModuleId: state.activeModuleId,
    submitting:    state.submitting,
    error:         state.error,
    pendingFiles,
    coverFile,
    // info
    setInfo,
    setCoverFile,
    // sections
    addSection,
    updateSection,
    removeSection,
    moveSectionUp,
    moveSectionDown,
    // modules
    addModule,
    updateModule,
    removeModule,
    // blocks
    setBlocks,
    addBlock,
    // navigation
    setStatus,
    setActiveTab:       (tab: WizardTab) => patch({ activeTab: tab }),
    setActiveModuleId:  (id: string | null) => patch({ activeModuleId: id }),
  };
}
