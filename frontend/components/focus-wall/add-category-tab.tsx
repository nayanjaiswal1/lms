"use client";

import { useState } from "react";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import styles from "./focus-wall.module.css";

const MAX_CATEGORY_NAME_LENGTH = 24;

interface AddCategoryTabProps {
  onAdd: (name: string) => Promise<boolean>;
}

// Mirrors sticky-note.tsx's draft pattern (plain input + onBlur, no
// react-hook-form) — a single-field inline toggle, not a page-level form.
export function AddCategoryTab({ onAdd }: AddCategoryTabProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [value, setValue] = useState("");

  async function commit() {
    const name = value.trim();
    setIsEditing(false);
    setValue("");
    if (!name) return;
    await onAdd(name);
  }

  if (isEditing) {
    return (
      <Input
        autoFocus
        className={cn("h-auto w-32 rounded-full px-3 py-2 text-xs uppercase", styles.tab)}
        maxLength={MAX_CATEGORY_NAME_LENGTH}
        placeholder="Category name"
        value={value}
        onBlur={commit}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") e.currentTarget.blur();
          if (e.key === "Escape") {
            setValue("");
            setIsEditing(false);
          }
        }}
      />
    );
  }

  return (
    <Button
      aria-label="Add a category"
      className={cn("touch-target h-auto rounded-full px-3 py-2 hover:bg-transparent", styles.tab)}
      variant="ghost"
      onClick={() => setIsEditing(true)}
    >
      <Plus aria-hidden className="size-4" />
    </Button>
  );
}
