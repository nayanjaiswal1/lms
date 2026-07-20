"use client";

import { useState } from "react";
import { toast } from "sonner";
import { KeyRound, Loader2, MoreVertical } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
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
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  registerPasskeyBeginAction,
  registerPasskeyFinishAction,
  renamePasskeyAction,
  deletePasskeyAction,
} from "@/app/(app)/settings/security/actions";
import {
  passkeysSupported,
  prepareCreationOptions,
  serializeCreatedCredential,
} from "@/lib/webauthn";

export interface PasskeyCredential {
  id: string;
  nickname: string;
  created_at: string;
  last_used_at: string | null;
  backup_state: boolean;
}

function formatDate(iso: string | null): string {
  if (!iso) return "Never";
  return new Date(iso).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

interface PasskeyManagerProps {
  credentials: PasskeyCredential[];
}

// Rename and delete are mutually exclusive dialogs, so one discriminated-union
// state slot covers both — keeps this component at 2 useState calls total.
type ActiveDialog =
  | { type: "rename"; credential: PasskeyCredential }
  | { type: "delete"; credential: PasskeyCredential }
  | null;

export function PasskeyManager({ credentials }: PasskeyManagerProps) {
  const [adding, setAdding] = useState(false);
  const [dialog, setDialog] = useState<ActiveDialog>(null);

  async function handleAdd() {
    if (!passkeysSupported()) {
      toast.error("This browser doesn't support passkeys.");
      return;
    }

    setAdding(true);
    try {
      const begin = await registerPasskeyBeginAction();
      if (!begin.ok || !begin.data) {
        toast.error(begin.error ?? "Couldn't start passkey registration.");
        return;
      }

      const credential = (await navigator.credentials.create(
        prepareCreationOptions(begin.data.options),
      )) as PublicKeyCredential | null;
      if (!credential) {
        toast.error("Passkey registration was cancelled.");
        return;
      }

      // Backend defaults to "Passkey" — renaming afterward is one click away.
      const finish = await registerPasskeyFinishAction(
        begin.data.handle,
        "",
        serializeCreatedCredential(credential),
      );
      if (!finish.ok) {
        toast.error(finish.error ?? "Couldn't save passkey.");
        return;
      }
      toast.success("Passkey added.");
    } catch (err) {
      console.error("[passkey] registration failed:", err);
      const detail = err instanceof Error ? `${err.name}: ${err.message}` : "";
      toast.error(detail ? `Passkey registration failed: ${detail}` : "Passkey registration failed. Please try again.");
    } finally {
      setAdding(false);
    }
  }

  async function handleRename(nickname: string) {
    if (dialog?.type !== "rename") return;
    const result = await renamePasskeyAction(dialog.credential.id, nickname);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Passkey renamed.");
    setDialog(null);
  }

  async function handleDelete() {
    if (dialog?.type !== "delete") return;
    const result = await deletePasskeyAction(dialog.credential.id);
    setDialog(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Passkey removed.");
  }

  return (
    <section aria-labelledby="passkeys-heading" className="card-base p-6 space-y-5">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold text-foreground" id="passkeys-heading">
            Passkeys
          </h2>
          <p className="text-sm text-muted-foreground">
            Sign in with Touch ID, Face ID, Windows Hello, or a security key — no password.
          </p>
        </div>
        <Button disabled={adding} size="sm" onClick={handleAdd}>
          {adding ? <Loader2 aria-hidden className="animate-spin" /> : <KeyRound aria-hidden className="h-4 w-4" />}
          Add a passkey
        </Button>
      </div>

      {credentials.length === 0 ? (
        <p className="text-sm text-muted-foreground empty-state py-6">
          No passkeys yet. Add one for faster, more secure sign-in.
        </p>
      ) : (
        <ul className="divide-y divide-border">
          {credentials.map((cred) => (
            <li className="flex items-center justify-between gap-4 py-3" key={cred.id}>
              <div className="min-w-0">
                <p className="text-sm font-medium text-foreground truncate">{cred.nickname}</p>
                <p className="text-xs text-muted-foreground">
                  Added {formatDate(cred.created_at)} · Last used {formatDate(cred.last_used_at)}
                </p>
              </div>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button aria-label={`Manage ${cred.nickname}`} className="touch-target" size="icon" variant="ghost">
                    <MoreVertical aria-hidden className="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onSelect={() => setDialog({ type: "rename", credential: cred })}>
                    Rename
                  </DropdownMenuItem>
                  <DropdownMenuItem
                    className="text-destructive focus:text-destructive"
                    onSelect={() => setDialog({ type: "delete", credential: cred })}
                  >
                    Remove
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </li>
          ))}
        </ul>
      )}

      <RenameDialog
        credential={dialog?.type === "rename" ? dialog.credential : null}
        // Remounts fresh whenever the target changes, so the input's initial
        // value always starts at that credential's current nickname.
        key={dialog?.type === "rename" ? dialog.credential.id : "none"}
        onOpenChange={(open) => !open && setDialog(null)}
        onSubmit={handleRename}
      />

      <AlertDialog
        open={dialog?.type === "delete"}
        onOpenChange={(open) => !open && setDialog(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Remove this passkey?</AlertDialogTitle>
            <AlertDialogDescription>
              {dialog?.type === "delete" ? `"${dialog.credential.nickname}" ` : ""}
              will no longer be able to sign in to your account. You can add it again later if you change your mind.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={handleDelete}
            >
              Remove
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </section>
  );
}

interface RenameDialogProps {
  credential: PasskeyCredential | null;
  onOpenChange: (open: boolean) => void;
  onSubmit: (nickname: string) => void;
}

function RenameDialog({ credential, onOpenChange, onSubmit }: RenameDialogProps) {
  const [nickname, setNickname] = useState(credential?.nickname ?? "");

  return (
    <Dialog open={credential !== null} onOpenChange={onOpenChange}>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Rename passkey</DialogTitle>
        </DialogHeader>
        <Input
          maxLength={80}
          value={nickname}
          onChange={(e) => setNickname(e.target.value)}
        />
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button disabled={nickname.trim().length === 0} onClick={() => onSubmit(nickname.trim())}>
            Save
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
