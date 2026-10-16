import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { FlaskConical } from "lucide-react";
import { SectionHeader } from "@/components/shared/section-header";
import { LabSettingsForm } from "@/app/org/settings/labs/lab-settings-form";
import type { LabSettings } from "@/app/org/settings/labs/actions";
import { apiGet } from "@/lib/server/api";
import { getMyPermissions } from "@/lib/server/permissions";
import { isPlatformAdmin } from "@/lib/labs/builder/server";
import { ImportLabsetButton } from "@/app/(app)/admin/labs/platform-labs/import-labset-button";
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

  const platformAdmin = await isPlatformAdmin();

  return (
    <div className="flex flex-col gap-6">
      <div className="card-base p-6">
        <SectionHeader
          description="Choose how debug labs look and behave for your organisation."
          icon={FlaskConical}
          title="Labs"
        />
        <LabSettingsForm settings={settings} />
      </div>
      {platformAdmin && (
        <div className="card-base flex flex-col gap-4 p-6">
          <SectionHeader
            description="Platform admin only. Publish the CI-verified debug labs into this environment when students see “Lab not available yet.”"
            icon={FlaskConical}
            title="Platform labs"
          />
          <ImportLabsetButton />
        </div>
      )}
    </div>
  );
}
