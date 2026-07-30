import { notFound } from "next/navigation";
import Link from "next/link";
import { CheckCircle2, Circle } from "lucide-react";
import { cn } from "@/lib/utils";
import { getPrepPlan } from "@/lib/server/interview-prep";
import { CodingItemPanel } from "@/components/interview-prep/coding-item-panel";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ planId: string }>;
  searchParams: Promise<{ item?: string }>;
}

export const metadata = { title: "Coding round — MindForge" };

export default async function InterviewPrepCodingPage({ params, searchParams }: Props) {
  const { planId } = await params;
  const { item: itemParam } = await searchParams;

  const plan = await getPrepPlan(planId).catch(() => null);
  if (!plan) notFound();

  const round = plan.rounds?.find((r) => r.round_type === "coding");
  const items = round?.items ?? [];
  if (!round || items.length === 0) notFound();

  const itemIndex = Math.min(Math.max(Number(itemParam ?? 0), 0), items.length - 1);
  const currentItem = items[itemIndex];

  return (
    <main className="page-container">
      <div className="flex flex-col gap-2 mb-6">
        <h1 className="page-title">Coding Round</h1>
        <p className="text-sm text-muted-foreground">{plan.job_title}</p>
      </div>

      <div className="flex flex-col gap-6 lg:flex-row lg:gap-8">
        <div className="order-2 lg:order-1 lg:w-56">
          <ol aria-label="Problem list" className="card-base flex flex-col gap-1.5 p-4">
            {items.map((it, i) => (
              <li key={it.id}>
                <Link
                  className={cn(
                    "flex items-center gap-2.5 rounded-md px-2 py-1.5 text-sm transition-colors duration-fast",
                    i === itemIndex && "bg-muted font-medium",
                  )}
                  href={`${ROUTES.interviewPrepCoding(planId)}?item=${i}`}
                >
                  {it.passed ? (
                    <CheckCircle2 aria-label="Passed" className="h-4 w-4 shrink-0 text-primary" />
                  ) : (
                    <Circle aria-label="Not attempted" className="h-4 w-4 shrink-0 text-muted-foreground" />
                  )}
                  <span className="flex-1 line-clamp-1">Problem {i + 1}</span>
                </Link>
              </li>
            ))}
          </ol>
        </div>

        <div className="order-1 flex-1 lg:order-2">
          <CodingItemPanel
            isLast={itemIndex === items.length - 1}
            item={currentItem}
            itemIndex={itemIndex}
            planId={planId}
            roundId={round.id}
          />
        </div>
      </div>
    </main>
  );
}
