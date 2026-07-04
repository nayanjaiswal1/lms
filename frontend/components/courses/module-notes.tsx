import { ModuleCompleteButton } from "@/components/courses/module-complete-button";

interface ModuleNotesProps {
  moduleId: string;
  title: string;
  html: string;
  initialCompleted: boolean;
}

export function ModuleNotes({ moduleId, title, html, initialCompleted }: ModuleNotesProps) {
  return (
    <article className="flex flex-col gap-4">
      {/* Visually hidden: the module title is already shown in the course
          sidebar rail (desktop) and the mobile drawer subheader, so showing
          it a third time here was pure duplication. Kept for screen readers
          and document outline. */}
      <h2 className="sr-only">{title}</h2>
      <div className="flex justify-end">
        {/* At xl+ this button moves into the ModuleProgressRail instead. */}
        <ModuleCompleteButton className="xl:hidden" initialCompleted={initialCompleted} moduleId={moduleId} />
      </div>
      <div className="card-base p-6">
        <div
          className="prose-content"
          dangerouslySetInnerHTML={{ __html: html }}
        />
      </div>
    </article>
  );
}
