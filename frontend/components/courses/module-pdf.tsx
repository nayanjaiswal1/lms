"use client";

import { updateProgressAction } from "@/lib/courses/actions";

interface ModulePDFProps {
  moduleId: string;
  presignedUrl: string;
  title: string;
}

export function ModulePDF({ moduleId, presignedUrl, title }: ModulePDFProps) {
  function handleLoad() {
    void updateProgressAction({ moduleID: moduleId, status: "in_progress" });
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-semibold">{title}</h2>
        <a
          href={presignedUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm text-primary hover:underline"
          onClick={() => void updateProgressAction({ moduleID: moduleId, status: "completed" })}
        >
          Open in new tab
        </a>
      </div>
      <iframe
        src={presignedUrl}
        title={title}
        className="min-h-[60dvh] w-full rounded-lg border border-border"
        onLoad={handleLoad}
      />
    </div>
  );
}
