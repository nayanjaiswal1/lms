"use client";

import { useState, type KeyboardEvent } from "react";
import { X } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

interface TagInputProps {
  value: string[];
  onChange: (value: string[]) => void;
  placeholder?: string;
  disabled?: boolean;
  className?: string;
}

// Chip-style multi-value text input: Enter or "," commits the current draft
// as a tag, Backspace on an empty draft pops the last tag. No dedicated
// tag-chip primitive existed in components/ui/ before this — everything else
// here (Input, Badge) is single-value, so this composes both rather than
// growing either one to cover a second shape.
export function TagInput({ value, onChange, placeholder, disabled, className }: TagInputProps) {
  const [draft, setDraft] = useState("");

  function commitDraft() {
    const tag = draft.trim();
    setDraft("");
    if (!tag || value.includes(tag)) return;
    onChange([...value, tag]);
  }

  function onKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter" || e.key === ",") {
      e.preventDefault();
      commitDraft();
      return;
    }
    if (e.key === "Backspace" && draft === "" && value.length > 0) {
      onChange(value.slice(0, -1));
    }
  }

  function removeTag(tag: string) {
    onChange(value.filter((t) => t !== tag));
  }

  return (
    <div
      className={cn(
        "flex min-h-11 w-full flex-wrap items-center gap-1.5 rounded-md border border-input bg-background px-3 py-2",
        "text-sm shadow-sm transition-colors has-[input:focus-visible]:ring-2 has-[input:focus-visible]:ring-ring",
        disabled && "cursor-not-allowed opacity-50",
        className,
      )}
    >
      {value.map((tag) => (
        <Badge className="gap-1 pr-1" key={tag} variant="secondary">
          {tag}
          {!disabled && (
            <button
              aria-label={`Remove ${tag}`}
              className="rounded-full hover:bg-foreground/10"
              type="button"
              onClick={() => removeTag(tag)}
            >
              <X aria-hidden className="h-3 w-3" />
            </button>
          )}
        </Badge>
      ))}
      <input
        className="min-w-24 flex-1 bg-transparent text-sm text-foreground outline-none placeholder:text-muted-foreground disabled:cursor-not-allowed"
        disabled={disabled}
        placeholder={value.length === 0 ? placeholder : undefined}
        value={draft}
        onBlur={commitDraft}
        onChange={(e) => setDraft(e.target.value)}
        onKeyDown={onKeyDown}
      />
    </div>
  );
}
