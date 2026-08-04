"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Download, Loader2, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
import { exportMyDataAction, deleteMyAccountAction } from "@/app/(app)/settings/privacy/actions";

export function PrivacySettings() {
  const [exporting, setExporting] = useState(false);
  const [deleteState, setDeleteState] = useState<{ open: boolean; password: string; pending: boolean }>({
    open: false,
    password: "",
    pending: false,
  });

  async function handleExport() {
    setExporting(true);
    const result = await exportMyDataAction();
    setExporting(false);
    if (result.error || !result.data) {
      toast.error(result.error ?? "Could not export your data.");
      return;
    }
    const blob = new Blob([JSON.stringify(result.data, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "mindforge-data-export.json";
    link.click();
    URL.revokeObjectURL(url);
  }

  async function handleDelete() {
    setDeleteState((s) => ({ ...s, pending: true }));
    const result = await deleteMyAccountAction(deleteState.password);
    // A successful call redirects server-side and never returns here.
    if (result?.error) {
      setDeleteState((s) => ({ ...s, pending: false }));
      toast.error(result.error);
    }
  }

  return (
    <div className="space-y-6">
      <section aria-labelledby="export-heading" className="card-base p-6 space-y-4">
        <div>
          <h2 className="text-lg font-semibold text-foreground" id="export-heading">
            Export your data
          </h2>
          <p className="text-sm text-muted-foreground">
            Download a copy of your profile, purchases, and activity as a JSON file.
          </p>
        </div>
        <Button disabled={exporting} size="sm" onClick={handleExport}>
          {exporting ? <Loader2 aria-hidden className="animate-spin" /> : <Download aria-hidden className="h-4 w-4" />}
          Download my data
        </Button>
      </section>

      <section aria-labelledby="delete-heading" className="card-base p-6 space-y-4 border-destructive/30">
        <div>
          <h2 className="text-lg font-semibold text-foreground" id="delete-heading">
            Delete your account
          </h2>
          <p className="text-sm text-muted-foreground">
            Permanently anonymizes your profile and signs you out of every device. This cannot be
            undone.
          </p>
        </div>
        <Button
          size="sm"
          variant="destructive"
          onClick={() => setDeleteState({ open: true, password: "", pending: false })}
        >
          <Trash2 aria-hidden className="h-4 w-4" />
          Delete my account
        </Button>
      </section>

      <AlertDialog
        open={deleteState.open}
        onOpenChange={(open) => setDeleteState((s) => ({ ...s, open }))}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete your account?</AlertDialogTitle>
            <AlertDialogDescription>
              Your name, email, and avatar will be permanently anonymized and every session ends
              immediately. If you sign in with a password, confirm it below. Leave it blank if you
              only sign in with Google, GitHub, Microsoft, or a passkey.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <Input
            autoComplete="current-password"
            disabled={deleteState.pending}
            placeholder="Current password (if you have one)"
            type="password"
            value={deleteState.password}
            onChange={(e) => setDeleteState((s) => ({ ...s, password: e.target.value }))}
          />
          <AlertDialogFooter>
            <AlertDialogCancel disabled={deleteState.pending}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              disabled={deleteState.pending}
              onClick={(e) => {
                e.preventDefault();
                void handleDelete();
              }}
            >
              {deleteState.pending ? <Loader2 aria-hidden className="animate-spin" /> : null}
              Delete my account
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
