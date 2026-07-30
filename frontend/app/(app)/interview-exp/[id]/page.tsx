import type { Metadata } from "next";

import { getPostDetail } from "@/lib/server/interview-exp";
import { Badge } from "@/components/ui/badge";
import { QnaBlock } from "@/components/interview-exp/qna-block";
import { AddQnaForm } from "@/components/interview-exp/add-qna-form";
import { AddEntryForm } from "@/components/interview-exp/add-entry-form";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

interface InterviewExpDetailPageProps {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: InterviewExpDetailPageProps): Promise<Metadata> {
  const { id } = await params;
  const post = await getPostDetail(id);
  return { title: post.title };
}

export default async function InterviewExpDetailPage({ params }: InterviewExpDetailPageProps) {
  const { id } = await params;
  const post = await getPostDetail(id);

  return (
    <main className="page-container-sm">
      <Breadcrumb
        items={[{ href: ROUTES.INTERVIEW_EXP, label: "Interview Experiences" }, { label: post.title }]}
      />
      <div className="page-header">
        <div>
          <h1 className="section-title">{post.title}</h1>
          <p className="text-sm text-muted-foreground">
            {post.company} · {post.position}
          </p>
          {post.tags.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-1.5">
              {post.tags.map((t) => (
                <Badge key={t} variant="secondary">
                  {t}
                </Badge>
              ))}
            </div>
          )}
        </div>
      </div>

      {post.entries.length > 0 && (
        <section className="mt-6 flex flex-col gap-6">
          <h2 className="section-title text-lg">Rounds</h2>
          {post.entries.map((entry) => (
            <div className="flex flex-col gap-3" key={entry.id}>
              <div className="card-base p-4">
                <h3 className="font-semibold text-foreground">{entry.round_label}</h3>
                <p className="mt-1 whitespace-pre-wrap text-sm text-muted-foreground">{entry.content}</p>
              </div>
              <div className="flex flex-col gap-3 pl-2">
                {entry.qna.map((qna) => (
                  <QnaBlock key={qna.id} qna={qna} />
                ))}
                <AddQnaForm target={{ type: "entry", id: entry.id }} />
              </div>
            </div>
          ))}
        </section>
      )}

      <section className="mt-6 flex flex-col gap-3">
        <h2 className="section-title text-lg">Questions</h2>
        {post.standalone_qna.map((qna) => (
          <QnaBlock key={qna.id} qna={qna} />
        ))}
        <AddQnaForm target={{ type: "post", id: post.id }} />
      </section>

      <section className="mt-8 border-t border-border pt-6">
        <h2 className="section-title mb-3 text-lg">Continue this thread</h2>
        <p className="mb-3 text-sm text-muted-foreground">
          Interviewed for the same role? Add your own round below.
        </p>
        <AddEntryForm postId={post.id} />
      </section>
    </main>
  );
}
