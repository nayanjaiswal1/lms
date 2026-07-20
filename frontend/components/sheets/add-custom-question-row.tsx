"use client";

import { useRef, useState } from "react";
import { Plus, Upload } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { DIFFICULTY_OPTIONS } from "@/lib/constants";
import { importSheetItemsExcelAction } from "@/lib/sheets/actions";
import type { CustomItemInput } from "@/lib/sheets/use-sheet-builder";
import type { Difficulty } from "@/lib/server/sheets";

const VALID_DIFFICULTIES: Difficulty[] = ["easy", "medium", "hard"];

interface AddCustomQuestionRowProps {
  onAddCustom: (input: CustomItemInput) => void;
  onAddCustomBulk: (inputs: CustomItemInput[]) => void;
}

function parseImportedRow(value: unknown): CustomItemInput | null {
  if (!value || typeof value !== "object") return null;
  const record = value as Record<string, unknown>;
  const title = typeof record.title === "string" ? record.title.trim() : "";
  if (!title) return null;

  const rawCategory = record.category ?? record.topic;
  const category = typeof rawCategory === "string" && rawCategory.trim() ? rawCategory.trim() : undefined;

  const rawDifficulty = typeof record.difficulty === "string" ? record.difficulty.trim().toLowerCase() : "";
  const difficulty = VALID_DIFFICULTIES.includes(rawDifficulty as Difficulty)
    ? (rawDifficulty as Difficulty)
    : undefined;

  return { title, category, difficulty };
}

export function AddCustomQuestionRow({ onAddCustom, onAddCustomBulk }: AddCustomQuestionRowProps) {
  const [draft, setDraft] = useState({ title: "", category: "", difficulty: "" as Difficulty | "" });
  const [importState, setImportState] = useState<{ pending: boolean; error?: string }>({ pending: false });
  const fileInputRef = useRef<HTMLInputElement>(null);

  function handleAdd() {
    const trimmedTitle = draft.title.trim();
    if (!trimmedTitle) return;
    onAddCustom({
      title: trimmedTitle,
      category: draft.category.trim() || undefined,
      difficulty: draft.difficulty || undefined,
    });
    setDraft({ title: "", category: "", difficulty: "" });
  }

  async function importFromJson(file: File) {
    try {
      const parsed: unknown = JSON.parse(await file.text());
      const list = Array.isArray(parsed) ? parsed : [];
      const items = list.map(parseImportedRow).filter((item): item is CustomItemInput => item !== null);
      if (items.length === 0) {
        setImportState({ pending: false, error: "No valid questions found in that JSON file." });
        return;
      }
      onAddCustomBulk(items);
      setImportState({ pending: false });
    } catch {
      setImportState({ pending: false, error: "Could not read that JSON file — expected an array of questions." });
    }
  }

  async function importFromExcel(file: File) {
    const formData = new FormData();
    formData.append("file", file);
    const result = await importSheetItemsExcelAction(formData);
    if (!result.ok || !result.data) {
      setImportState({ pending: false, error: result.error ?? "Could not read that file." });
      return;
    }
    onAddCustomBulk(result.data.map((item) => ({ title: item.title, category: item.category, difficulty: item.difficulty })));
    setImportState({ pending: false });
  }

  async function handleFileSelected(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;

    setImportState({ pending: true });
    if (file.name.toLowerCase().endsWith(".json")) {
      await importFromJson(file);
    } else {
      await importFromExcel(file);
    }
  }

  return (
    <div className="flex flex-col gap-2 rounded-md border border-dashed border-border p-3">
      <div className="flex flex-col gap-2 md:flex-row md:items-center">
        <Input
          className="md:flex-1"
          placeholder="Add your own question — title"
          value={draft.title}
          onChange={(e) => setDraft((prev) => ({ ...prev, title: e.target.value }))}
        />
        <Input
          className="md:w-40"
          placeholder="Topic"
          value={draft.category}
          onChange={(e) => setDraft((prev) => ({ ...prev, category: e.target.value }))}
        />
        <Select
          value={draft.difficulty}
          onValueChange={(value) => setDraft((prev) => ({ ...prev, difficulty: value as Difficulty }))}
        >
          <SelectTrigger className="md:w-32">
            <SelectValue placeholder="Difficulty" />
          </SelectTrigger>
          <SelectContent>
            {DIFFICULTY_OPTIONS.map((d) => (
              <SelectItem key={d.value} value={d.value}>
                {d.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Button disabled={!draft.title.trim()} size="sm" type="button" onClick={handleAdd}>
          <Plus aria-hidden className="h-4 w-4" />
          Add question
        </Button>
        <Button
          disabled={importState.pending}
          size="sm"
          type="button"
          variant="outline"
          onClick={() => fileInputRef.current?.click()}
        >
          <Upload aria-hidden className="h-4 w-4" />
          {importState.pending ? "Importing…" : "Import JSON/Excel"}
        </Button>
        <input
          accept=".json,.xlsx"
          className="hidden"
          ref={fileInputRef}
          type="file"
          onChange={handleFileSelected}
        />
      </div>
      {importState.error && <p className="text-sm text-destructive">{importState.error}</p>}
    </div>
  );
}
