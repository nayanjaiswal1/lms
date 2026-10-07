"use client";

import { FileText } from "lucide-react";
import { cn } from "@/lib/utils";
import type { WikiTemplate } from "@/lib/server/wiki";

import { Button } from "@/components/ui/button";
interface WikiTemplatePickerProps {
  templates: WikiTemplate[];
  selected: string | null;
  onSelect: (templateId: string | null) => void;
}

export function WikiTemplatePicker({ templates, selected, onSelect }: WikiTemplatePickerProps) {
  return (
    <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
      <Button aria-pressed={selected === null}
        className={cn(
          "flex flex-col items-center gap-1.5 rounded-lg border p-3 text-center text-xs transition-colors duration-fast",
          selected === null ? "border-primary bg-muted" : "border-border hover:bg-muted",
        )}
        type="button"
        variant="unstyled"
        onClick={() => onSelect(null)}
      >
        <FileText aria-hidden className="h-5 w-5 text-muted-foreground" />
        Blank page
      </Button>
      {templates.map((t) => (
        <Button aria-pressed={selected === t.id}
          className={cn(
            "flex flex-col items-center gap-1.5 rounded-lg border p-3 text-center text-xs transition-colors duration-fast",
            selected === t.id ? "border-primary bg-muted" : "border-border hover:bg-muted",
          )}
          key={t.id}
          type="button"
          variant="unstyled"
          onClick={() => onSelect(t.id)}
        >
          <FileText aria-hidden className="h-5 w-5 text-muted-foreground" />
          <span className="line-clamp-2">{t.name}</span>
        </Button>
      ))}
    </div>
  );
}
