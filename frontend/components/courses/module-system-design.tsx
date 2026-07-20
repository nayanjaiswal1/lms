import { Boxes } from "lucide-react";
import { getModuleDesign } from "@/lib/server/design";
import { renderModuleMarkdown } from "@/lib/courses/markdown";
import { ModuleSystemDesignClient } from "@/components/courses/module-system-design-client";

interface ModuleSystemDesignProps {
  moduleId: string;
  title: string;
  contentBody: string | null;
}

export async function ModuleSystemDesign({ moduleId, title, contentBody }: ModuleSystemDesignProps) {
  const design = await getModuleDesign(moduleId);
  if (!design) {
    return (
      <div className="empty-state flex-col gap-2 py-16">
        <Boxes aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="text-sm text-muted-foreground">This design question is not available yet.</p>
      </div>
    );
  }

  const guidanceSegments = contentBody ? renderModuleMarkdown(contentBody).segments : [];

  return (
    <ModuleSystemDesignClient
      guidanceSegments={guidanceSegments}
      initialAttempts={design.attempts}
      initialChat={design.chat}
      initialSelected={design.selected}
      moduleId={moduleId}
      title={title}
    />
  );
}
