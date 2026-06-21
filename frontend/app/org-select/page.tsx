import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { Building2 } from "lucide-react";

import { AuthPageShell } from "@/components/auth/auth-page-shell";
import { OrgSelectList } from "@/app/org-select/org-select-list";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Select organisation",
  description: "Choose which organisation to continue with.",
};

interface Org {
  id: string;
  slug: string;
  name: string;
  role: string;
}

interface MeResponse {
  data: {
    user: { id: string; name: string; email: string; avatar_url: string };
    orgs: Org[];
    onboarding_completed: boolean;
  };
}

async function getOrgs(): Promise<{ user: MeResponse["data"]["user"]; orgs: Org[] } | null> {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get("access_token")?.value;
  if (!accessToken) return null;

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) return null;

  try {
    const response = await fetch(`${apiUrl}/api/auth/me`, {
      headers: { Cookie: `access_token=${accessToken}` },
      cache: "no-store",
    });
    if (!response.ok) return null;
    const body: MeResponse = await response.json();
    return { user: body.data.user, orgs: body.data.orgs };
  } catch {
    return null;
  }
}

export default async function OrgSelectPage() {
  const data = await getOrgs();
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
