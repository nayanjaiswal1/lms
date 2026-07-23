"use client";

import { useState } from "react";
import { toast } from "sonner";
import { MoreVertical } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import ROUTES from "@/lib/routes";
import { deleteSheetAction, unsubscribeSheetAction, updateSheetAction } from "@/lib/sheets/actions";
import type { UserSheetSummary } from "@/lib/server/sheets";

interface SheetCardMenuProps {
  sheet: UserSheetSummary;
}

export function SheetCardMenu({ sheet }: SheetCardMenuProps) {
  const isOwner = sheet.role === "owner";
  const canManage = isOwner && !sheet.is_system;

  const [ui, setUi] = useState<{ dialog: "edit" | "delete" | null; pending: boolean }>({
    dialog: null,
    pending: false,
  });
  const [form, setForm] = useState({ name: sheet.name, description: sheet.description ?? "" });

  function openEdit() {
    setForm({ name: sheet.name, description: sheet.description ?? "" });
    setUi({ dialog: "edit", pending: false });
  }

  async function saveEdit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setUi((s) => ({ ...s, pending: true }));
    const result = await updateSheetAction(sheet.id, {
      name: form.name.trim(),
      description: form.description.trim(),
    });
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't update this sheet.");
      setUi((s) => ({ ...s, pending: false }));
      return;
    }
    toast.success("Sheet updated.");
    setUi({ dialog: null, pending: false });
  }

  async function confirmDelete() {
    setUi((s) => ({ ...s, pending: true }));
    const result = await deleteSheetAction(sheet.id);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't delete this sheet.");
      setUi((s) => ({ ...s, pending: false }));
      return;
    }
    toast.success("Sheet deleted.");
    setUi({ dialog: null, pending: false });
  }

  async function unsubscribe() {
    const result = await unsubscribeSheetAction(sheet.id);
    if (!result.ok) toast.error(result.error ?? "Couldn't unsubscribe from this sheet.");
    else toast.success("Unsubscribed.");
  }

  async function share() {
    const url = `${window.location.origin}${ROUTES.sheetJoin(sheet.slug)}`;
    await navigator.clipboard.writeText(url);
    toast.success("Share link copied.");
  }

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            aria-label={`${sheet.name} options`}
            className="touch-target shrink-0"
            size="icon"
            variant="ghost"
            onClick={(e) => e.stopPropagation()}
          >
            <MoreVertical aria-hidden className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" onClick={(e) => e.stopPropagation()}>
          {canManage && <DropdownMenuItem onSelect={openEdit}>Edit</DropdownMenuItem>}
          {canManage && <DropdownMenuItem onSelect={share}>Share</DropdownMenuItem>}
          {!isOwner && <DropdownMenuItem onSelect={unsubscribe}>Unsubscribe</DropdownMenuItem>}
          {canManage && (
            <>
              <DropdownMenuSeparator />
              <DropdownMenuItem
                className="text-destructive focus:text-destructive"
                onSelect={() => setUi({ dialog: "delete", pending: false })}
              >
                Delete
              </DropdownMenuItem>
            </>
          )}
        </DropdownMenuContent>
      </DropdownMenu>

      <Dialog open={ui.dialog === "edit"} onOpenChange={(open) => setUi((s) => ({ ...s, dialog: open ? "edit" : null }))}>
        <DialogContent className="modal-responsive sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Edit sheet</DialogTitle>
          </DialogHeader>
          <form className="form-stack" onSubmit={saveEdit}>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="sheet-edit-name">Name</Label>
              <Input
                required
                disabled={ui.pending}
                id="sheet-edit-name"
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="sheet-edit-description">Description</Label>
              <Textarea
                disabled={ui.pending}
                id="sheet-edit-description"
                rows={3}
                value={form.description}
                onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
              />
            </div>
            <DialogFooter>
              <Button
                disabled={ui.pending}
                type="button"
                variant="outline"
                onClick={() => setUi({ dialog: null, pending: false })}
              >
                Cancel
              </Button>
              <Button disabled={ui.pending} type="submit">
                {ui.pending ? "Saving…" : "Save"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <AlertDialog
        open={ui.dialog === "delete"}
        onOpenChange={(open) => setUi((s) => ({ ...s, dialog: open ? "delete" : null }))}
      >
        <AlertDialogContent className="modal-responsive">
          <AlertDialogHeader>
            <AlertDialogTitle>Delete &quot;{sheet.name}&quot;?</AlertDialogTitle>
            <AlertDialogDescription>
              This permanently deletes the sheet and every subscriber&apos;s access to it. This can&apos;t be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={ui.pending}>Cancel</AlertDialogCancel>
            <AlertDialogAction disabled={ui.pending} onClick={confirmDelete}>
              {ui.pending ? "Deleting…" : "Delete"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
