"use client";

import { useQueryState } from "nuqs";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { WikiNewSpaceDialog } from "@/components/wiki/wiki-new-space-dialog";

export function WikiNewSpaceTrigger() {
  const [open, setOpen] = useQueryState("newSpace", { defaultValue: "" });
  const isOpen = open === "1";

  return (
    <>
      <Button onClick={() => void setOpen("1")}>
        <Plus aria-hidden className="mr-2 h-4 w-4" />
        New space
      </Button>
      <WikiNewSpaceDialog open={isOpen} onClose={() => void setOpen("")} />
    </>
  );
}
