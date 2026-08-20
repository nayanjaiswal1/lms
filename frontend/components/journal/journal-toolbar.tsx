import Link from "next/link";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";
import { JournalCategoryChips } from "@/components/journal/journal-category-chips";
import { JournalQuickAdd } from "@/components/journal/journal-quick-add";
import { JournalSearchBar } from "@/components/journal/journal-search-bar";
import type { JournalCategoryNode } from "@/lib/server/journal";

interface JournalToolbarProps {
  categories: JournalCategoryNode[];
}

export function JournalToolbar({ categories }: JournalToolbarProps) {
  return (
    <div className="mb-4 flex flex-col gap-3">
      <JournalQuickAdd categories={categories} />
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <JournalSearchBar />
        <Button asChild className="touch-target w-fit gap-1.5" size="sm" variant="outline">
          <Link href={ROUTES.JOURNAL_NEW}>
            <Plus aria-hidden className="size-4" />
            Open full form
          </Link>
        </Button>
      </div>
      <JournalCategoryChips categories={categories} />
    </div>
  );
}
