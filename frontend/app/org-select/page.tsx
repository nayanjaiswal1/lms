import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Building2 } from "lucide-react";

import { AuthPageShell } from "@/components/auth/auth-page-shell";
import { OrgSelectList } from "@/app/org-select/org-select-list";
import { getAuthMe } from "@/lib/server/auth";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Select organisation",
  description: "Choose which organisation to continue with.",
};

export default async function OrgSelectPage() {
  const data = await getAuthMe();
  if (!data) redirect(ROUTES.LOGIN);

  const { user, orgs } = data;

  return (
    <AuthPageShell
      title="Choose your organisation"
      description={`Welcome back, ${user.name}. Select which workspace to continue with.`}
      alternatePrompt="Wrong account?"
      alternateLabel="Sign in with a different account"
      alternateHref={ROUTES.LOGIN}
    >
      {orgs.length === 0 ? (
        <div className="flex flex-col items-center gap-3 py-6 text-center text-muted-foreground">
          <Building2 aria-hidden className="h-10 w-10 opacity-40" />
          <p className="text-sm">You don&apos;t belong to any organisation yet.</p>
        </div>
      ) : (
        <OrgSelectList orgs={orgs} />
      )}
    </AuthPageShell>
  );
}
