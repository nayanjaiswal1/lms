"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Monitor } from "lucide-react";
import { Badge } from "@/components/ui/badge";
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
import { revokeSessionAction } from "@/app/(app)/settings/security/actions";
import { formatOptionalDate } from "@/components/settings/format-optional-date";

export interface DeviceSession {
  id: string;
  device_hint: string | null;
  ip: string | null;
  started_at: string;
  last_active_at: string;
  current: boolean;
}

interface SessionsCardProps {
  sessions: DeviceSession[];
}

export function SessionsCard({ sessions }: SessionsCardProps) {
  const [target, setTarget] = useState<DeviceSession | null>(null);

  async function handleRevoke() {
    if (!target) return;
    const result = await revokeSessionAction(target.id);
    setTarget(null);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't sign out that device.");
      return;
    }
    toast.success("Device signed out.");
  }

  return (
    <section aria-labelledby="sessions-heading" className="card-base p-6 space-y-5">
      <div>
        <h2 className="text-lg font-semibold text-foreground" id="sessions-heading">
          Signed-in devices
        </h2>
        <p className="text-sm text-muted-foreground">
          Sign out any device you don&apos;t recognise. It is cut off within minutes.
        </p>
      </div>

      <ul className="divide-y divide-border">
        {sessions.map((s) => (
          <li className="flex-between gap-4 py-3" key={s.id}>
            <div className="flex min-w-0 items-center gap-3">
              <Monitor aria-hidden className="h-5 w-5 shrink-0 text-muted-foreground" />
              <div className="min-w-0">
                <p className="text-sm font-medium text-foreground truncate">
                  {s.device_hint ?? "Unknown device"}
                  {s.current && <Badge className="ml-2" variant="secondary">This device</Badge>}
                </p>
                <p className="text-xs text-muted-foreground truncate">
                  {s.ip ? `${s.ip}.x · ` : ""}Signed in {formatOptionalDate(s.started_at)} · Active {formatOptionalDate(s.last_active_at)}
                </p>
              </div>
            </div>
            <Button className="touch-target" size="sm" variant="outline" onClick={() => setTarget(s)}>
              Sign out
            </Button>
          </li>
        ))}
      </ul>

      <AlertDialog open={target !== null} onOpenChange={(open) => !open && setTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Sign out this device?</AlertDialogTitle>
            <AlertDialogDescription>
              {target?.current
                ? "This is the device you're using now — you'll be taken to the sign-in page."
                : "It will need to sign in again."}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={handleRevoke}
            >
              Sign out
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </section>
  );
}
