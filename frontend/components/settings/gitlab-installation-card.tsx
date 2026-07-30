"use client";

import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import {
  verifyGitlabInstallationAction,
  setDefaultGitlabInstallationAction,
  disconnectGitlabInstallationAction,
} from "@/app/(app)/settings/integrations/actions";

export interface GitlabInstallationStatus {
  id: string;
  name: string;
  is_default: boolean;
  connected: boolean;
  base_url?: string;
  tier?: string;
  auth_kind?: string;
  status?: string;
  gitlab_username?: string;
  has_oauth_app?: boolean;
  last_error?: string | null;
  last_verified_at?: string | null;
  created_at?: string | null;
}

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "Never";
  return new Date(iso).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

interface GitlabInstallationCardProps {
  installation: GitlabInstallationStatus;
}

export function GitlabInstallationCard({ installation }: GitlabInstallationCardProps) {
  const router = useRouter();

  async function handleVerify() {
    const result = await verifyGitlabInstallationAction(installation.id);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    if (result.data?.status === "active") {
      toast.success("Connection verified — token is working.");
    } else {
      toast.error("Verification failed — see the error below.");
    }
    router.refresh();
  }

  async function handleSetDefault() {
    const result = await setDefaultGitlabInstallationAction(installation.id);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`"${installation.name}" is now the default connection.`);
  }

  async function handleDisconnect() {
    const result = await disconnectGitlabInstallationAction(installation.id);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`"${installation.name}" disconnected.`);
  }

  return (
    <div className="flex flex-wrap items-start justify-between gap-4 rounded-lg border border-border p-4">
      <div className="min-w-0 flex items-center gap-3">
        <ShieldCheck aria-hidden className="h-8 w-8 flex-shrink-0 text-primary" />
        <div className="min-w-0">
          <p className="text-sm font-medium text-foreground truncate">
            {installation.name}
            {installation.is_default && <Badge className="ml-2 align-middle" variant="secondary">Default</Badge>}
          </p>
          <p className="text-xs text-muted-foreground truncate">{installation.base_url}</p>
          <p className="text-xs text-muted-foreground">
            {installation.auth_kind === "oauth" ? "OAuth service account" : "Personal access token"}
            {installation.gitlab_username ? ` · @${installation.gitlab_username}` : ""}
            {" · Last verified "}
            {formatDate(installation.last_verified_at)}
          </p>
          <div className="mt-1 flex flex-wrap gap-1">
            <Badge variant={installation.status === "active" ? "secondary" : "destructive"}>
              {installation.status}
            </Badge>
            <Badge variant="outline">{installation.tier}</Badge>
            {installation.has_oauth_app && <Badge variant="outline">Members can connect</Badge>}
          </div>
          {installation.last_error && (
            <p className="mt-2 text-xs text-destructive">{installation.last_error}</p>
          )}
        </div>
      </div>
      <div className="flex flex-shrink-0 flex-wrap gap-2">
        <Button className="touch-target" size="sm" variant="outline" onClick={handleVerify}>
          Verify
        </Button>
        {!installation.is_default && (
          <Button className="touch-target" size="sm" variant="outline" onClick={handleSetDefault}>
            Set default
          </Button>
        )}
        <AlertDialog>
          <AlertDialogTrigger asChild>
            <Button className="touch-target" size="sm" variant="outline">
              Disconnect
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Disconnect &quot;{installation.name}&quot;?</AlertDialogTitle>
              <AlertDialogDescription>
                {installation.is_default
                  ? "This is the default connection — set another one as default first if other connections exist."
                  : "Any project assignment pinned to this connection will need a different one before it can be deleted."}
                {" "}Every member&apos;s personal GitLab connection tied to it will stop working too.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction
                className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                onClick={handleDisconnect}
              >
                Disconnect
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </div>
    </div>
  );
}
