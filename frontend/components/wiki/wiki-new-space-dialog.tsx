"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { createSpaceAction } from "@/lib/wiki/actions";
import ROUTES from "@/lib/routes";

interface WikiNewSpaceDialogProps {
  open: boolean;
  onClose: () => void;
}

export function WikiNewSpaceDialog({ open, onClose }: WikiNewSpaceDialogProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    const name = (form.get("name") as string)?.trim();
    if (!name) return;
    const description = (form.get("description") as string)?.trim();

    startTransition(async () => {
      const result = await createSpaceAction({
        name,
        description: description || undefined,
        visibility: "members",
      });
      if (!result.ok || !result.data) {
        toast.error(result.error ?? "Couldn't create that space.");
        return;
      }
      toast.success("Space created");
      onClose();
      router.push(ROUTES.wikiSpace(result.data.slug));
    });
  }

  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="modal-responsive sm:max-w-md">
        <DialogHeader>
          <DialogTitle>New space</DialogTitle>
        </DialogHeader>
        <form className="form-stack" onSubmit={handleSubmit}>
          <Input autoFocus required name="name" placeholder="Space name" />
          <Textarea name="description" placeholder="What's this space for? (optional)" rows={3} />
          <DialogFooter>
            <Button disabled={pending} type="button" variant="outline" onClick={onClose}>Cancel</Button>
            <Button disabled={pending} type="submit">{pending ? "Creating…" : "Create space"}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
