"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import {
  ChevronUp, ChevronDown, Trash2, Plus, ChevronRight, GripVertical,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { MODULE_CONTENT_TYPE_OPTIONS } from "@/lib/constants";
import type { DraftSection, DraftModule } from "@/lib/courses/draft-types";

// ─── Module row ───────────────────────────────────────────────────────────────

interface ModuleRowProps {
  module:      DraftModule;
  isActive:    boolean;
  onUpdate:    (patch: Partial<DraftModule>) => void;
  onRemove:    () => void;
  onSelect:    () => void;
}

function ModuleRow({ module, isActive, onUpdate, onRemove, onSelect }: ModuleRowProps) {
  return (
    <div
      className={cn(
        "group flex items-start gap-2 rounded-md border border-transparent px-2 py-2 transition-colors",
        isActive ? "border-primary/40 bg-primary/5" : "hover:bg-muted/50",
      )}
    >
      <GripVertical className="mt-2.5 h-3.5 w-3.5 shrink-0 text-muted-foreground/40" aria-hidden />

      <div className="flex flex-1 flex-col gap-2 min-w-0">
        <div className="flex items-center gap-2">
          <Input
            className="h-8 text-sm"
            placeholder="Lesson title"
            value={module.title}
            onChange={(e) => onUpdate({ title: e.target.value })}
          />
          <Select value={module.type} onValueChange={(v) => onUpdate({ type: v })}>
            <SelectTrigger aria-label="Module type" className="h-8 w-32 shrink-0 text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {MODULE_CONTENT_TYPE_OPTIONS.map((o) => (
                <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="flex items-center gap-4 text-xs text-muted-foreground">
          <label className="flex items-center gap-1.5 cursor-pointer">
            <Checkbox
              checked={module.is_free_preview}
              onCheckedChange={(v) => onUpdate({ is_free_preview: Boolean(v) })}
            />
            Free preview
          </label>
          <div className="flex items-center gap-1">
            <span>Est.</span>
            <input
              className="w-10 rounded border border-input bg-background px-1 text-center text-xs"
              min={1}
              type="number"
              value={module.estimated_minutes}
              onChange={(e) => onUpdate({ estimated_minutes: Number(e.target.value) || 5 })}
            />
            <span>min</span>
          </div>
        </div>
      </div>

      <div className="flex shrink-0 items-center gap-1">
        <Button
          aria-label="Edit content"
          size="icon"
          type="button"
          variant="ghost"
          className="h-7 w-7"
          onClick={onSelect}
        >
          <ChevronRight className="h-3.5 w-3.5" />
        </Button>
        <Button
          aria-label="Remove module"
          size="icon"
          type="button"
          variant="ghost"
          className="h-7 w-7 text-muted-foreground hover:text-destructive"
          onClick={onRemove}
        >
          <Trash2 className="h-3.5 w-3.5" />
        </Button>
      </div>
    </div>
  );
}

// ─── Section card ─────────────────────────────────────────────────────────────

interface SectionCardProps {
  section:         DraftSection;
  index:           number;
  total:           number;
  activeModuleId:  string | null;
  onUpdateSection: (title: string) => void;
  onRemoveSection: () => void;
  onMoveUp:        () => void;
  onMoveDown:      () => void;
  onAddModule:     (type: string) => void;
  onUpdateModule:  (modId: string, patch: Partial<DraftModule>) => void;
  onRemoveModule:  (modId: string) => void;
  onSelectModule:  (modId: string) => void;
}

function SectionCard({
  section, index, total, activeModuleId,
  onUpdateSection, onRemoveSection, onMoveUp, onMoveDown,
  onAddModule, onUpdateModule, onRemoveModule, onSelectModule,
}: SectionCardProps) {
  const [open, setOpen] = useState(true);

  return (
    <div className="card-base">
      {/* Section header */}
      <div className="flex items-center gap-2 p-3 border-b border-border">
        <button
          aria-label={open ? "Collapse section" : "Expand section"}
          type="button"
          onClick={() => setOpen((v) => !v)}
        >
          <ChevronRight className={cn("h-4 w-4 text-muted-foreground transition-transform", open && "rotate-90")} />
        </button>
        <Input
          className="h-8 flex-1 text-sm font-medium border-0 shadow-none focus-visible:ring-0 bg-transparent px-0"
          placeholder="Section title"
          value={section.title}
          onChange={(e) => onUpdateSection(e.target.value)}
        />
        <div className="flex items-center gap-1">
          <Button aria-label="Move section up"   disabled={index === 0}         onClick={onMoveUp}   size="icon" type="button" variant="ghost" className="h-7 w-7"><ChevronUp   className="h-3.5 w-3.5" /></Button>
          <Button aria-label="Move section down" disabled={index === total - 1} onClick={onMoveDown} size="icon" type="button" variant="ghost" className="h-7 w-7"><ChevronDown className="h-3.5 w-3.5" /></Button>
          <Button aria-label="Remove section" onClick={onRemoveSection} size="icon" type="button" variant="ghost" className="h-7 w-7 text-muted-foreground hover:text-destructive"><Trash2 className="h-3.5 w-3.5" /></Button>
        </div>
      </div>

      {/* Modules */}
      {open && (
        <div className="flex flex-col gap-1 p-2">
          {section.modules.length === 0 && (
            <p className="px-2 py-3 text-xs text-muted-foreground text-center">No lessons yet. Add one below.</p>
          )}
          {section.modules.map((mod) => (
            <ModuleRow
              key={mod.localId}
              module={mod}
              isActive={activeModuleId === mod.localId}
              onUpdate={(patch) => onUpdateModule(mod.localId, patch)}
              onRemove={() => onRemoveModule(mod.localId)}
              onSelect={() => onSelectModule(mod.localId)}
            />
          ))}
          <Button
            className="mt-1 border-dashed text-muted-foreground"
            size="sm"
            type="button"
            variant="outline"
            onClick={() => onAddModule("notes")}
          >
            <Plus className="mr-1.5 h-3.5 w-3.5" />
            Add lesson
          </Button>
        </div>
      )}
    </div>
  );
}

// ─── Structure tab ────────────────────────────────────────────────────────────

interface StructureTabProps {
  sections:          DraftSection[];
  activeModuleId:    string | null;
  onAddSection:      () => void;
  onUpdateSection:   (localId: string, title: string) => void;
  onRemoveSection:   (localId: string) => void;
  onMoveSectionUp:   (index: number) => void;
  onMoveSectionDown: (index: number) => void;
  onAddModule:       (sectionLocalId: string, type?: string) => void;
  onUpdateModule:    (sectionLocalId: string, moduleLocalId: string, patch: Partial<DraftModule>) => void;
  onRemoveModule:    (sectionLocalId: string, moduleLocalId: string) => void;
  onSelectModule:    (moduleLocalId: string) => void;
}

export function StructureTab({
  sections, activeModuleId,
  onAddSection, onUpdateSection, onRemoveSection, onMoveSectionUp, onMoveSectionDown,
  onAddModule, onUpdateModule, onRemoveModule, onSelectModule,
}: StructureTabProps) {
  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-muted-foreground">
            Organize your course into sections and lessons. Click <ChevronRight className="inline h-3.5 w-3.5" /> on any lesson to edit its content.
          </p>
        </div>
        <Button type="button" onClick={onAddSection}>
          <Plus className="mr-1.5 h-4 w-4" />
          Add section
        </Button>
      </div>

      {sections.length === 0 && (
        <div className="empty-state py-16">
          <p className="text-muted-foreground">No sections yet. Add a section to start building your course.</p>
        </div>
      )}

      {sections.map((section, index) => (
        <SectionCard
          key={section.localId}
          section={section}
          index={index}
          total={sections.length}
          activeModuleId={activeModuleId}
          onUpdateSection={(title) => onUpdateSection(section.localId, title)}
          onRemoveSection={() => onRemoveSection(section.localId)}
          onMoveUp={() => onMoveSectionUp(index)}
          onMoveDown={() => onMoveSectionDown(index)}
          onAddModule={(type) => onAddModule(section.localId, type)}
          onUpdateModule={(modId, patch) => onUpdateModule(section.localId, modId, patch)}
          onRemoveModule={(modId) => onRemoveModule(section.localId, modId)}
          onSelectModule={onSelectModule}
        />
      ))}

      {sections.length > 0 && (
        <Button className="border-dashed" type="button" variant="outline" onClick={onAddSection}>
          <Plus className="mr-1.5 h-4 w-4" />
          Add another section
        </Button>
      )}
    </div>
  );
}
