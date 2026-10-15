import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { FlaskConical } from "lucide-react";
import { SectionHeader } from "@/components/shared/section-header";
import { LabSettingsForm } from "@/app/org/settings/labs/lab-settings-form";
import type { LabSettings } from "@/app/org/settings/labs/actions";
import { apiGet } from "@/lib/server/api";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";

export const metadata: Metadata = {
  title: "Labs — Organisation Settings",
};

export default async function OrgLabsSettingsPage() {
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ORG)) {
    notFound();
  }

  const settings = await apiGet<LabSettings>("/api/admin/labs/settings");

  return (
    <div className="card-base p-6">
      <SectionHeader
        description="Choose how debug labs look and behave for your organisation."
        icon={FlaskConical}
        title="Labs"
      />
      <LabSettingsForm settings={settings} />
    </div>
  );
}
