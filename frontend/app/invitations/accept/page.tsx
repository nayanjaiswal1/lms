import type { Metadata } from "next";
import { GraduationCap } from "lucide-react";
import { InvitationResponseForm } from "@/app/invitations/accept/invitation-response-form";
import { apiAction } from "@/lib/server/api";

export const metadata: Metadata = { title: "Batch invitation" };

type InvitationStatus = "pending" | "accepted" | "declined" | "expired";

interface InvitationPreview {
  email: string;
  batch_name: string;
  org_name: string;
  expires_at: string;
  status: InvitationStatus;
}

const CLOSED_MESSAGE: Record<Exclude<InvitationStatus, "pending">, string> = {
  accepted: "This invitation has already been accepted.",
  declined: "This invitation was declined.",
  expired: "This invitation has expired. Ask your instructor to send a new one.",
};

interface BatchInvitationPageProps {
  searchParams: Promise<{ token?: string }>;
}

/** Landing page for batch-import invite emails (/invitations/accept?token=…).
 *  Not public: signed-out visitors go through /login?next=… and return here. */
export default async function BatchInvitationPage({ searchParams }: BatchInvitationPageProps) {
  const { token } = await searchParams;
  const preview = token
    ? await apiAction<InvitationPreview>("GET", `/api/invitations/preview/${encodeURIComponent(token)}`)
    : null;
  const invitation = preview?.data;

  return (
    <main className="flex min-h-dvh items-center justify-center p-4">
      <div className="card-base flex w-full max-w-sm flex-col gap-4 p-8">
        <GraduationCap aria-hidden className="mx-auto h-12 w-12 text-muted-foreground" />
        {!token || !invitation ? (
          <p className="text-center text-muted-foreground">
            {!token || preview?.status === 404
              ? "This invitation link is not valid. Open it again from your email."
              : (preview?.error ?? "Could not load this invitation.")}
          </p>
        ) : (
          <>
            <div className="text-center">
              <h1 className="page-title">Join {invitation.batch_name}</h1>
              <p className="mt-2 text-muted-foreground">
                {invitation.org_name} invited <span className="font-medium text-foreground">{invitation.email}</span>.
                You must be signed in with that email to accept.
              </p>
            </div>
            {invitation.status === "pending" ? (
              <InvitationResponseForm token={token} />
            ) : (
              <p className="text-center text-muted-foreground">{CLOSED_MESSAGE[invitation.status]}</p>
            )}
          </>
        )}
      </div>
    </main>
  );
}
