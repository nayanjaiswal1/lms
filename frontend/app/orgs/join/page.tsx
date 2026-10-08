import type { Metadata } from "next";
import { JoinOrgForm } from "@/app/orgs/join/join-org-form";

export const metadata: Metadata = { title: "Join organization" };

interface JoinOrgPageProps {
  searchParams: Promise<{ token?: string }>;
}

/** Landing page for org and workspace invite emails (/orgs/join?token=…).
 *  Not public: the proxy sends signed-out visitors to /login?next=…, so they
 *  come straight back here after signing in. */
export default async function JoinOrgPage({ searchParams }: JoinOrgPageProps) {
  const { token } = await searchParams;

  return (
    <main className="flex min-h-dvh items-center justify-center p-4">
      <div className="card-base w-full max-w-sm p-8">
        {token ? (
          <JoinOrgForm token={token} />
        ) : (
          <p className="text-center text-muted-foreground">This invite link is incomplete. Open it again from your email.</p>
        )}
      </div>
    </main>
  );
}
