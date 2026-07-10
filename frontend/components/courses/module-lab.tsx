import { Terminal } from "lucide-react";
import { ModuleLabClient } from "@/components/courses/module-lab-client";
import { getModuleLab } from "@/lib/server/labs";

interface ModuleLabProps {
  moduleId: string;
  title: string;
}

export async function ModuleLab({ moduleId, title }: ModuleLabProps) {
  const moduleLab = await getModuleLab(moduleId);
  if (!moduleLab) {
    return (
      <div className="empty-state flex-col gap-2 py-16">
        <Terminal aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="text-sm text-muted-foreground">Lab not available yet.</p>
      </div>
    );
  }

  return <ModuleLabClient initialSession={moduleLab.initialSession} lab={moduleLab.lab} title={title} />;
}
