"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import type { WikiTemplate } from "@/lib/server/wiki";
import { createPageAction } from "@/lib/wiki/actions";
import { WikiTemplatePicker } from "@/components/wiki/wiki-template-picker";

interface WikiNewPageDialogProps {
  open: boolean;
  parentId: string | null;
  spaceId: string;
  templates: WikiTemplate[];
  onClose: () => void;
}

export function WikiNewPageDialog({ open, parentId, spaceId, templates, onClose }: WikiNewPageDialogProps) {
  const router = useRouter();
  const [title, setTitle] = useState("");
  const [templateId, setTemplateId] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function handleCreate() {
    if (!title.trim()) return;
    startTransition(async () => {
      const result = await createPageAction(spaceId, {
        title: title.trim(),
        parent_id: parentId ?? undefined,
        template_id: templateId ?? undefined,
      });
      if (!result.ok) {
        toast.error(result.error ?? "Couldn't create that page.");
        return;
      }
      toast.success("Page created");
      setTitle("");
      setTemplateId(null);
      onClose();
      router.refresh();
    });
  }

  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="modal-responsive sm:max-w-md">
        <DialogHeader>
          <DialogTitle>New page</DialogTitle>
        </DialogHeader>
        <div className="form-stack">
          <Input
            autoFocus
            placeholder="Page title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
          />
          <WikiTemplatePicker selected={templateId} templates={templates} onSelect={setTemplateId} />
        </div>
        <DialogFooter>
          <Button disabled={pending} variant="outline" onClick={onClose}>Cancel</Button>
          <Button disabled={pending || !title.trim()} onClick={handleCreate}>
            {pending ? "Creating…" : "Create page"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
