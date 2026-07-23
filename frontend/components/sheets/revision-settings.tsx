"use client";

import { useState } from "react";
import Link from "next/link";
import { Settings2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { GROWTH_SCHEME_OPTIONS, revisionSchedulePreview, type GrowthScheme } from "@/lib/constants";
import { updateSheetSettingsAction } from "@/lib/sheets/actions";
import { useNotesPanel } from "@/components/sheets/notes-panel-context";

interface RevisionSettingsProps {
  sheetId: string;
  baseRevisionDays: number;
  growthScheme: GrowthScheme;
  isOwner: boolean;
  isEditMode: boolean;
  toggleEditModeHref: string;
}

const ORDINALS = ["1st", "2nd", "3rd", "4th", "5th"];

function clampDays(raw: string, fallback: number): number {
  const n = Math.round(Number(raw));
  return Number.isFinite(n) && n > 0 ? Math.min(365, n) : fallback;
}

export function RevisionSettings({
  sheetId,
  baseRevisionDays,
  growthScheme,
  isOwner,
  isEditMode,
  toggleEditModeHref,
}: RevisionSettingsProps) {
  const [open, setOpen] = useState(false);
  // Grouped into one state object to stay within the 2-useState budget —
  // daysInput is the raw text the user is typing, kept separate from any
  // clamped/coerced number so the field never snaps back to "0" or the last
  // valid value mid-edit (that fight-the-user bug is why manual entry broke).
  const [form, setForm] = useState({ daysInput: String(baseRevisionDays), scheme: growthScheme });
  const notesPanel = useNotesPanel();

  function openDialog() {
    setForm({ daysInput: String(baseRevisionDays), scheme: growthScheme });
    setOpen(true);
  }

  async function save(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const days = clampDays(form.daysInput, baseRevisionDays);
    const result = await updateSheetSettingsAction(sheetId, days, form.scheme);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't save your revision settings.");
      return;
    }
    toast.success("Revision settings saved.");
    setOpen(false);
  }

  const previewDays = clampDays(form.daysInput, baseRevisionDays);
  const preview = revisionSchedulePreview(form.scheme, previewDays);

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button aria-label="Sheet settings" className="touch-target" size="icon" variant="ghost">
            <Settings2 aria-hidden className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          {isOwner && (
            <DropdownMenuItem asChild>
              <Link href={toggleEditModeHref}>{isEditMode ? "Done editing" : "Edit problems"}</Link>
            </DropdownMenuItem>
          )}
          <DropdownMenuItem onSelect={openDialog}>Revision settings</DropdownMenuItem>
          {notesPanel.open && (
            <>
              <DropdownMenuSeparator />
              <DropdownMenuItem onSelect={notesPanel.toggleEditing}>
                {notesPanel.editing ? "Done editing notes" : "Edit notes"}
              </DropdownMenuItem>
              <DropdownMenuItem onSelect={notesPanel.closePanel}>Hide notes</DropdownMenuItem>
            </>
          )}
        </DropdownMenuContent>
      </DropdownMenu>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="modal-responsive sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Revision settings</DialogTitle>
          </DialogHeader>
          <form className="form-stack" onSubmit={save}>
            <div>
              <label className="text-xs font-medium text-muted-foreground" htmlFor="revision-growth-scheme">
                Growth scheme
              </label>
              <Select
                value={form.scheme}
                onValueChange={(v) => setForm((f) => ({ ...f, scheme: v as GrowthScheme }))}
              >
                <SelectTrigger id="revision-growth-scheme">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {GROWTH_SCHEME_OPTIONS.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div>
              <label className="text-xs font-medium text-muted-foreground" htmlFor="revision-base-days">
                Base interval (days)
              </label>
              <Input
                id="revision-base-days"
                inputMode="numeric"
                max={365}
                min={1}
                type="number"
                value={form.daysInput}
                onChange={(e) => setForm((f) => ({ ...f, daysInput: e.target.value }))}
                onFocus={(e) => e.target.select()}
              />
            </div>

            <div className="rounded-md border border-border bg-muted/30 p-3">
              <p className="mb-2 text-xs font-medium text-muted-foreground">Schedule preview</p>
              <ul className="flex flex-wrap gap-x-4 gap-y-1 text-sm tabular-nums text-foreground">
                {preview.map((d, i) => (
                  <li key={i}>
                    <span className="text-muted-foreground">{ORDINALS[i]}:</span> {d}d
                  </li>
                ))}
              </ul>
            </div>

            <p className="text-xs text-muted-foreground">
              Applies to this sheet only. Marking a problem solved schedules the 1st revision; clicking
              &quot;Next&quot; on a due item schedules the 2nd, then the 3rd, and so on.
            </p>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setOpen(false)}>
                Cancel
              </Button>
              <Button type="submit">Save</Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}
