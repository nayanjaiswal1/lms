"use client";

import { useState } from "react";
import type { Difficulty, Sheet, SheetItem } from "@/lib/server/sheets";

export interface CustomItemInput {
  title: string;
  category?: string;
  difficulty?: Difficulty;
}

export interface CustomItem extends CustomItemInput {
  id: string;
}

export interface PreviewRow {
  key: string;
  title: string;
  category?: string | null;
  difficulty?: Difficulty | null;
  topicTag?: string;
  sourceLabel: string;
  isCustom: boolean;
  customId?: string;
}

let customItemCounter = 0;

// Selection state for the /sheets/new builder: which existing sheets are
// checked, which of their (deduped) problems got unchecked, and any
// hand-typed problems the user added on top. Kept in one hook so the panel
// component stays within the 2-useState convention.
export function useSheetBuilder(allSheets: Sheet[], itemsBySheetId: Record<string, SheetItem[]>) {
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [excludedTopics, setExcludedTopics] = useState<string[]>([]);
  const [customItems, setCustomItems] = useState<CustomItem[]>([]);

  function toggleSelected(id: string, checked: boolean) {
    setSelectedIds((prev) => (checked ? [...prev, id] : prev.filter((existing) => existing !== id)));
  }

  function toggleExcluded(topicTag: string, excluded: boolean) {
    setExcludedTopics((prev) =>
      excluded ? [...prev, topicTag] : prev.filter((existing) => existing !== topicTag),
    );
  }

  function addCustomItem(input: CustomItemInput) {
    customItemCounter += 1;
    setCustomItems((prev) => [...prev, { id: `custom-${customItemCounter}`, ...input }]);
  }

  function addCustomItems(inputs: CustomItemInput[]) {
    const added = inputs.map((input) => {
      customItemCounter += 1;
      return { id: `custom-${customItemCounter}`, ...input };
    });
    setCustomItems((prev) => [...prev, ...added]);
  }

  function removeCustomItem(id: string) {
    setCustomItems((prev) => prev.filter((item) => item.id !== id));
  }

  const selectedSheets = allSheets.filter((s) => selectedIds.includes(s.id));

  const rows: PreviewRow[] = [];
  if (selectedSheets.length === 1) {
    for (const item of itemsBySheetId[selectedSheets[0].id] ?? []) {
      rows.push({
        key: item.id,
        title: item.title,
        category: item.category,
        difficulty: item.difficulty,
        topicTag: item.topic_tag,
        sourceLabel: selectedSheets[0].name,
        isCustom: false,
      });
    }
  } else if (selectedSheets.length >= 2) {
    const seenTopics = new Set<string>();
    for (const sheet of selectedSheets) {
      for (const item of itemsBySheetId[sheet.id] ?? []) {
        if (seenTopics.has(item.topic_tag)) continue;
        seenTopics.add(item.topic_tag);
        rows.push({
          key: item.id,
          title: item.title,
          category: item.category,
          difficulty: item.difficulty,
          topicTag: item.topic_tag,
          sourceLabel: sheet.name,
          isCustom: false,
        });
      }
    }
  }
  for (const item of customItems) {
    rows.push({
      key: item.id,
      title: item.title,
      category: item.category,
      difficulty: item.difficulty,
      sourceLabel: "Custom",
      isCustom: true,
      customId: item.id,
    });
  }

  return {
    selectedIds,
    selectedSheets,
    excludedTopics,
    customItems,
    rows,
    toggleSelected,
    toggleExcluded,
    addCustomItem,
    addCustomItems,
    removeCustomItem,
  };
}
