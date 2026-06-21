import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect, notFound } from "next/navigation";
import Link from "next/link";
import { Building2, Users, Globe, Shield } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { Org } from "@/lib/orgs/types";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Overview — Organisation Settings",
};

async function getCurrentOrgId(): Promise<string | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString(),
    ) as { org_id?: string; role?: string };
    return payload.org_id ?? null;
  } catch {
    return null;
  }
}

async function getOrgRole(): Promise<string | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString(),
    ) as { role?: string };
    return payload.role ?? null;
  } catch {
    return null;
  }
}

async function fetchOrg(orgId: string): Promise<Org | null> {
  const store = await cookies();
  const access = store.get("access_token")?.value ?? "";
  const apiUrl = process.env.BACKEND_URL ?? "";
  try {
    const res = await fetch(`${apiUrl}/api/orgs/${orgId}`, {
      headers: { Cookie: `access_token=${access}` },
      cache: "no-store",
    });
    if (!res.ok) return null;
    const body = (await res.json()) as { data: Org };
    return body.data;
  } catch {
    return null;
  }
}

function statusVariant(status: string): "default" | "secondary" | "destructive" | "outline" {
  switch (status) {
    case "active": return "default";
    case "onboarding": return "secondary";
    case "suspended": return "destructive";
    default: return "outline";
  }
}

function statusLabel(status: string): string {
  switch (status) {
    case "pending_verification": return "Pending Verification";
    case "onboarding": return "Setting Up";
    case "active": return "Active";
    case "suspended": return "Suspended";
    case "archived": return "Archived";
    default: return status;
  }
}

export default async function OrgSettingsPage() {
  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const [org, role] = await Promise.all([fetchOrg(orgId), getOrgRole()]);
  if (!org) notFound();

  const seatPct =
    org.seat_limit !== null && org.seat_limit > 0
      ? Math.min(100, Math.round((org.active_member_count / org.seat_limit) * 100))
      : null;

  return (
    <div className="space-y-6">
      {/* Org identity card */}
      <div className="card-base p-6">
        <div className="flex items-start gap-4">
          <div className="h-14 w-14 rounded-lg bg-muted flex items-center justify-center flex-shrink-0">
            {org.logo_url ? (
              /* eslint-disable-next-line @next/next/no-img-element */
              <img
                alt={`${org.name} logo`}
                className="h-14 w-14 rounded-lg object-cover"
                src={org.logo_url}
              />
            ) : (
              <Building2 aria-hidden className="h-7 w-7 text-muted-foreground" />
            )}
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex flex-wrap items-center gap-2 mb-1">
              <h2 className="text-xl font-semibold text-foreground truncate">
                {org.name}
              </h2>
              <Badge variant={statusVariant(org.status)}>
                {statusLabel(org.status)}
              </Badge>
            </div>
            <p className="text-sm text-muted-foreground mb-1">
              Slug: <span className="font-mono text-foreground">{org.slug}</span>
            </p>
            {org.description && (
              <p className="text-sm text-muted-foreground mt-2">{org.description}</p>
            )}
          </div>
        </div>

        {/* Seat usage */}
        <div className="mt-6 border-t border-border pt-5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-foreground">Members</span>
            <span className="text-sm text-muted-foreground">
              {org.active_member_count}
              {org.seat_limit !== null ? ` / ${org.seat_limit} seats` : " active"}
            </span>
          </div>
          {seatPct !== null && (
            <div className="progress-track" role="progressbar" aria-valuenow={seatPct} aria-valuemin={0} aria-valuemax={100}>
              {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width requires inline style */}
              <div className="progress-fill" style={{ "--progress": `${seatPct}%` } as React.CSSProperties} />
            </div>
          )}
        </div>

        {/* Activate button for onboarding orgs */}
        {org.status === "onboarding" && role === "owner" && (
          <div className="mt-5 p-4 rounded-lg bg-muted border border-border">
            <p className="text-sm text-muted-foreground mb-3">
              Your organisation setup is almost complete. Activate to make it live for your members.
            </p>
            <Button asChild size="sm">
              <Link href={ROUTES.ORG_SETUP}>Complete Setup</Link>
            </Button>
          </div>
        )}
      </div>

      {/* Quick links */}
      <div className="grid-responsive-2 gap-4">
        <Link
          className="card-interactive p-5 flex items-center gap-4"
          href={ROUTES.ORG_SETTINGS_MEMBERS}
        >
          <div className="h-10 w-10 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
            <Users aria-hidden className="h-5 w-5 text-primary" />
          </div>
          <div>
            <p className="font-medium text-foreground">Members</p>
            <p className="text-sm text-muted-foreground">Manage team access and roles</p>
          </div>
        </Link>

        <Link
          className="card-interactive p-5 flex items-center gap-4"
          href={ROUTES.ORG_SETTINGS_DOMAINS}
        >
          <div className="h-10 w-10 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
            <Globe aria-hidden className="h-5 w-5 text-primary" />
          </div>
          <div>
            <p className="font-medium text-foreground">Domains</p>
            <p className="text-sm text-muted-foreground">Configure verified domains</p>
          </div>
        </Link>

        <Link
          className="card-interactive p-5 flex items-center gap-4"
          href={ROUTES.ORG_SETTINGS_AUTH}
        >
          <div className="h-10 w-10 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
            <Shield aria-hidden className="h-5 w-5 text-primary" />
          </div>
          <div>
            <p className="font-medium text-foreground">Authentication</p>
            <p className="text-sm text-muted-foreground">SSO and login policies</p>
          </div>
        </Link>
      </div>
    </div>
  );
}
