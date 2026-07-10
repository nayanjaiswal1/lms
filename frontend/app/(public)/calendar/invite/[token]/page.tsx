import type { Metadata } from "next";
import { AcceptInviteForm } from "@/app/(public)/calendar/invite/[token]/accept-invite-form";

export const metadata: Metadata = { title: "Accept calendar invite" };

interface AcceptInvitePageProps {
  params: Promise<{ token: string }>;
}

export default async function AcceptCalendarInvitePage({ params }: AcceptInvitePageProps) {
  const { token } = await params;

  return (
    <main className="flex min-h-dvh items-center justify-center p-4">
      <div className="card-base w-full max-w-sm p-8">
        <AcceptInviteForm token={token} />
      </div>
    </main>
  );
}
