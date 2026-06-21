import { updateProgressAction } from "@/lib/courses/actions";

interface ModuleNotesProps {
  moduleId: string;
  title: string;
  body: string;
}

export async function ModuleNotes({ moduleId, title, body }: ModuleNotesProps) {
  await updateProgressAction({ moduleID: moduleId, status: "completed" });

  return (
    <article className="flex flex-col gap-4">
      <h2 className="text-xl font-semibold">{title}</h2>
      <div className="card-base p-6">
        <div className="prose-content whitespace-pre-wrap">{body}</div>
      </div>
    </article>
  );
}
