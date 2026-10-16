import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { FlaskConical } from "lucide-react";
import { SectionHeader } from "@/components/shared/section-header";
import { isPlatformAdmin } from "@/lib/labs/builder/server";
import { ImportLabsetButton } from "./import-labset-button";

export const metadata: Metadata = { title: "Platform labs" };

export default async function PlatformLabsPage() {
  if (!(await isPlatformAdmin())) notFound();

  return (
    <div className="page-container">
      <div className="card-base flex flex-col gap-4 p-6">
        <SectionHeader
          description="Publish the CI-verified debug labs into this environment. Use it when students see “Lab not available yet.” CI must have published a labset for this environment's lab runtime first."
          icon={FlaskConical}
          title="Platform labs"
        />
        <ImportLabsetButton />
      </div>
    </div>
  );
}
