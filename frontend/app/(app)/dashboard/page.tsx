import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { resolvePersona } from "@/lib/auth/personas";
import ROUTES from "@/lib/routes";
import { getCurrentUser } from "@/lib/server/auth";
import { getMyPermissions } from "@/lib/server/permissions";
import { AdminDashboard } from "./_components/admin-dashboard";
import { LearnerDashboard } from "./_components/learner-dashboard";
import { MentorDashboard } from "./_components/mentor-dashboard";
import { TeachDashboard } from "./_components/teach-dashboard";

export const metadata: Metadata = {
  title: "Dashboard",
  description: "Your MindForge dashboard.",
};

const PERSONA_COOKIE = "mf_persona";

interface DashboardPageProps {
  searchParams: Promise<{ scope?: string; scope_id?: string }>;
}

// The persona (learn/teach/mentor/admin/support/viewer) is resolved from
// permission codes plus the optional mf_persona cookie; see lib/auth/personas.ts.
export default async function DashboardPage({ searchParams }: DashboardPageProps) {
  const [user, params, perms, store] = await Promise.all([
    getCurrentUser(),
    searchParams,
    getMyPermissions(),
    cookies(),
  ]);
  if (!user) redirect(ROUTES.LOGIN);

  const firstName = user.name.trim().split(" ")[0] || user.email;
  const persona = resolvePersona(perms, store.get(PERSONA_COOKIE)?.value);

  switch (persona) {
    case "admin":
      return <AdminDashboard firstName={firstName} perms={perms} />;
    case "teach":
      return <TeachDashboard firstName={firstName} perms={perms} />;
    case "mentor":
      return <MentorDashboard firstName={firstName} perms={perms} />;
    case "support":
      return redirect(ROUTES.SUPPORT_QUEUE);
    default:
      return (
        <LearnerDashboard
          coursesOnly={persona === "viewer"}
          firstName={firstName}
          scope={params.scope}
          scopeId={params.scope_id}
          userId={user.id}
        />
      );
  }
}
