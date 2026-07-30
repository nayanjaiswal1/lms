import type { Metadata } from "next";
import Link from "next/link";
import { MessageSquare } from "lucide-react";

import ROUTES from "@/lib/routes";
import { listPosts } from "@/lib/server/interview-exp";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { PostFilters } from "@/components/interview-exp/post-filters";

export const metadata: Metadata = { title: "Interview Experiences" };

interface InterviewExpPageProps {
  searchParams: Promise<{ company?: string; position?: string; tag?: string; q?: string }>;
}

export default async function InterviewExpPage({ searchParams }: InterviewExpPageProps) {
  const { company, position, tag, q } = await searchParams;
  const posts = await listPosts({ company, position, tag, q });

  return (
    <main className="page-container-sm">
      <div className="page-header">
        <div>
          <h1 className="page-title">Interview Experiences</h1>
          <p className="text-sm text-muted-foreground">
            Company and position-tagged interview write-ups, Q&amp;A, and discussion — shared across every org.
          </p>
        </div>
        <div className="flex gap-2">
          <Button asChild variant="outline">
            <Link href={ROUTES.INTERVIEW_EXP_FAQ}>Frequently asked</Link>
          </Button>
          <Button asChild>
            <Link href={ROUTES.INTERVIEW_EXP_NEW}>Share an experience</Link>
          </Button>
        </div>
      </div>

      <PostFilters />

      {posts.length === 0 ? (
        <div className="empty-state mt-6">
          <MessageSquare aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="text-muted-foreground font-medium">No experiences match yet.</p>
          <p className="text-sm text-muted-foreground">Be the first to share one, or a question.</p>
        </div>
      ) : (
        <ul className="mt-6 flex flex-col divide-y divide-border rounded-md border border-border">
          {posts.map((post) => (
            <li className="relative flex flex-col gap-1.5 px-4 py-3" key={post.id}>
              <Link className="absolute inset-0 z-raised" href={ROUTES.interviewExpPost(post.id)}>
                <span className="sr-only">Open {post.title}</span>
              </Link>
              <div className="flex items-center gap-2">
                <h2 className="truncate font-semibold text-foreground">{post.title}</h2>
              </div>
              <p className="text-sm text-muted-foreground">
                {post.company} · {post.position}
              </p>
              {post.tags.length > 0 && (
                <div className="flex flex-wrap gap-1.5">
                  {post.tags.map((t) => (
                    <Badge key={t} variant="secondary">
                      {t}
                    </Badge>
                  ))}
                </div>
              )}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
