import { marked } from "marked";
import { updateProgressAction } from "@/lib/courses/actions";
import { RewardResultNotifier } from "@/components/rewards/reward-result-notifier";

interface ModuleNotesProps {
  moduleId: string;
  title: string;
  body: string;
}

export async function ModuleNotes({ moduleId, title, body }: ModuleNotesProps) {
  const result = await updateProgressAction({ moduleID: moduleId, status: "completed" });
  const rewards = result.ok ? (result.data?.rewards ?? null) : null;

  const html = await marked.parse(body, { async: false, gfm: true });

  return (
    <article className="flex flex-col gap-4">
      <RewardResultNotifier result={rewards} />
      <h2 className="text-xl font-semibold">{title}</h2>
      <div className="card-base p-6">
        <div
          className="prose-content"
          dangerouslySetInnerHTML={{ __html: html }}
        />
      </div>
    </article>
  );
}
