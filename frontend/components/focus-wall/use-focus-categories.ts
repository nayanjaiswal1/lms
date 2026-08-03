"use client";

import { useState } from "react";
import { toast } from "sonner";
import { createCategoryAction, deleteCategoryAction } from "@/app/(app)/focus-wall/actions";
import type { FocusCategory } from "@/lib/server/focus-wall";

// Isolated so FocusWallCanvas's own useState count stays at the two that
// actually drive its canvas (notes, zoom) — category CRUD is a self-contained
// concern with its own state, same reasoning as useFullscreen.
export function useFocusCategories(initial: FocusCategory[]) {
  const [categories, setCategories] = useState(initial);

  async function addCategory(name: string): Promise<boolean> {
    const result = await createCategoryAction(name);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Couldn't add that category.");
      return false;
    }
    setCategories((prev) => [...prev, result.data as FocusCategory]);
    return true;
  }

  async function removeCategory(id: string) {
    const prev = categories;
    setCategories((current) => current.filter((c) => c.id !== id));
    const result = await deleteCategoryAction(id);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't remove that category.");
      setCategories(prev);
    }
  }

  return { categories, addCategory, removeCategory };
}
