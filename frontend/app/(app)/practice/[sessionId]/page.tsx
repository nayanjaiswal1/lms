import { notFound } from "next/navigation";
import { getPracticeSession } from "@/lib/server/practice";
import { PracticeQuestion } from "@/components/practice/practice-question";
import { SessionProgress } from "@/components/practice/session-progress";

interface Props {
  params: Promise<{ sessionId: string }>;
  searchParams: Promise<{ q?: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { sessionId } = await params;
  const session = await getPracticeSession(sessionId).catch(() => null);
  if (!session) return { title: "Practice — MindForge" };
  return { title: `${session.technology} practice — MindForge` };
}

export default async function PracticeSessionPage({ params, searchParams }: Props) {
  const { sessionId } = await params;
  const { q } = await searchParams;

  const session = await getPracticeSession(sessionId).catch(() => null);
  if (!session) notFound();

  const items = session.items ?? [];
  const position = Math.min(Math.max(Number(q ?? 0), 0), Math.max(items.length - 1, 0));
  const currentItem = items[position];

  return (
    <main className="page-container py-8">
      <div className="flex flex-col gap-2 mb-6">
        <h1 className="page-title capitalize">{session.technology} Interview Practice</h1>
        <p className="text-sm text-muted-foreground capitalize">
          {session.difficulty} · {session.question_count} questions · {session.status}
        </p>
      </div>

      <div className="flex flex-col gap-6 lg:flex-row lg:gap-8">
        <div className="order-2 lg:order-1 lg:w-56">
          <SessionProgress items={items} currentPosition={position} />
        </div>

        <div className="order-1 flex-1 lg:order-2">
          {currentItem ? (
            <PracticeQuestion
              sessionId={session.id}
              item={currentItem}
              isLast={position === items.length - 1}
            />
          ) : (
            <div className="card-base p-8 text-center">
              <p className="text-muted-foreground">Session complete. All questions answered.</p>
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
