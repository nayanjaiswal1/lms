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

type SensitiveAction = "export" | "delete";

interface ConfirmState {
  action: SensitiveAction | null;
  password: string;
  code: string;
  pending: boolean;
}

const CLOSED: ConfirmState = { action: null, password: "", code: "", pending: false };

const COPY: Record<SensitiveAction, { title: string; description: string; confirm: string }> = {
  export: {
    title: "Confirm it's you",
    description: "Your export contains personal data, so confirm your identity before downloading it.",
    confirm: "Download my data",
  },
  delete: {
    title: "Delete your account?",
    description:
      "Your name, email, and avatar will be permanently anonymized and every session ends immediately.",
    confirm: "Delete my account",
  },
};

function downloadJson(data: Record<string, unknown>) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = "mindforge-data-export.json";
  link.click();
  URL.revokeObjectURL(url);
}

export function PrivacySettings() {
  const [state, setState] = useState<ConfirmState>(CLOSED);
  const copy = state.action ? COPY[state.action] : null;

  async function handleConfirm() {
    const stepUp = { password: state.password, code: state.code };
    setState((s) => ({ ...s, pending: true }));
    if (state.action === "export") {
      const result = await exportMyDataAction(stepUp);
      if (result.error || !result.data) {
        setState((s) => ({ ...s, pending: false }));
        toast.error(result.error ?? "Could not export your data.");
        return;
      }
      setState(CLOSED);
      downloadJson(result.data);
      return;
    }
    const result = await deleteMyAccountAction(stepUp);
    // A successful call redirects server-side and never returns here.
    if (result?.error) {
      setState((s) => ({ ...s, pending: false }));
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
        <Button size="sm" onClick={() => setState({ ...CLOSED, action: "export" })}>
          <Download aria-hidden className="h-4 w-4" />
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
        <Button size="sm" variant="destructive" onClick={() => setState({ ...CLOSED, action: "delete" })}>
          <Trash2 aria-hidden className="h-4 w-4" />
          Delete my account
        </Button>
      </section>

      <AlertDialog open={state.action !== null} onOpenChange={(open) => !open && setState(CLOSED)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{copy?.title}</AlertDialogTitle>
            <AlertDialogDescription>
              {copy?.description} Enter your password if you sign in with one, and a code from your
              authenticator app if two-factor authentication is on. Leave a field blank if it
              doesn&apos;t apply to you.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <Input
            aria-label="Current password"
            autoComplete="current-password"
            disabled={state.pending}
            placeholder="Current password (if you have one)"
            type="password"
            value={state.password}
            onChange={(e) => setState((s) => ({ ...s, password: e.target.value }))}
          />
          <Input
            aria-label="Two-factor code"
            autoComplete="one-time-code"
            disabled={state.pending}
            placeholder="Two-factor or recovery code (if enabled)"
            value={state.code}
            onChange={(e) => setState((s) => ({ ...s, code: e.target.value }))}
          />
          <AlertDialogFooter>
            <AlertDialogCancel disabled={state.pending}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              disabled={state.pending}
              onClick={(e) => {
                e.preventDefault();
                void handleConfirm();
              }}
            >
              {state.pending ? <Loader2 aria-hidden className="animate-spin" /> : null}
              {copy?.confirm}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
