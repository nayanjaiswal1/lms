"use client";

import { useQueryState } from "nuqs";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { JournalCategoryNode } from "@/lib/server/journal";

interface JournalCategoryChipsProps {
  categories: JournalCategoryNode[];
}

export function JournalCategoryChips({ categories }: JournalCategoryChipsProps) {
  const [category, setCategory] = useQueryState("category", { defaultValue: "", shallow: false });
  const [subcategory, setSubcategory] = useQueryState("subcategory", { defaultValue: "", shallow: false });

  if (categories.length === 0) return null;

  const subcategories = categories.find((c) => c.category === category)?.subcategories ?? [];

  function selectCategory(next: string | null) {
    void setCategory(next);
    void setSubcategory(null);
  }

  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex flex-wrap gap-1.5">
        <Button
          aria-pressed={category === ""}
          className={cn("touch-target px-2.5 text-xs", category === "" && "bg-accent")}
          size="sm"
          type="button"
          variant="ghost"
          onClick={() => selectCategory(null)}
        >
          All
        </Button>
        {categories.map((c) => (
          <Button
            aria-pressed={category === c.category}
            className={cn("touch-target px-2.5 text-xs", category === c.category && "bg-accent text-primary")}
            key={c.category}
            size="sm"
            type="button"
            variant="ghost"
            onClick={() => selectCategory(c.category)}
          >
            {c.category}
          </Button>
        ))}
      </div>
      {category !== "" && subcategories.length > 0 && (
        <div className="flex flex-wrap gap-1.5 pl-3">
          <Button
            aria-pressed={subcategory === ""}
            className={cn("touch-target px-2.5 text-xs", subcategory === "" && "bg-accent")}
            size="sm"
            type="button"
            variant="ghost"
            onClick={() => void setSubcategory(null)}
          >
            All {category}
          </Button>
          {subcategories.map((s) => (
            <Button
              aria-pressed={subcategory === s}
              className={cn("touch-target px-2.5 text-xs", subcategory === s && "bg-accent text-primary")}
              key={s}
              size="sm"
              type="button"
              variant="ghost"
              onClick={() => void setSubcategory(s)}
            >
              {s}
            </Button>
          ))}
        </div>
      )}
    </div>
  );
}
