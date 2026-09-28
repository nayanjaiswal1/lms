"use client";

import { useState } from "react";
import { Library } from "lucide-react";
import { LibraryPickerDialog } from "@/components/library/library-picker-dialog";

interface SectionLibraryMenuProps {
  sectionId: string;
}

/** "Add from library" trigger next to "Add module" in the course-builder
 * section menu (app/(app)/courses/[slug]/edit/page.tsx) — opens the picker
 * dialog, which appends the placed item at the end of the section and
 * refreshes the page itself. */
export function SectionLibraryMenu({ sectionId }: SectionLibraryMenuProps) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        className="flex cursor-pointer list-none items-center gap-1.5 text-xs font-bold text-primary hover:underline"
        type="button"
        onClick={() => setOpen(true)}
      >
        <Library aria-hidden className="h-3.5 w-3.5" />
        Add from library
      </button>
      <LibraryPickerDialog open={open} sectionId={sectionId} onAdded={() => {}} onOpenChange={setOpen} />
    </>
  );
}
