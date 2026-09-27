import type { Metadata } from "next";
import Link from "next/link";

import { AllFeedbackTable } from "@/components/workspace/feedback/all-feedback-table";
import { RateTeammateRow } from "@/components/workspace/feedback/rate-teammate-row";
import { ShowcaseToggle } from "@/components/workspace/feedback/showcase-toggle";
import { getMemberReport, getWorkspaceFeedback } from "@/lib/workspace/phase5-server";
import { getCurrentUser } from "@/lib/server/auth";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Feedback",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceFeedbackPage({ params }: PageProps) {
  const { id } = await params;
  const currentUser = await getCurrentUser();
  const [feedback, myReport] = await Promise.all([
    getWorkspaceFeedback(id),
    currentUser ? getMemberReport(id, currentUser.id) : Promise.resolve(null),
  ]);
  const givenByUserId = new Map(feedback.given.map((row) => [row.to_user.user_id, row]));

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="page-title">Feedback</h1>
        {feedback.window_closes_at && (
          <p className="text-sm text-muted-foreground">
            {feedback.open
              ? `Open until ${new Date(feedback.window_closes_at).toLocaleDateString()}`
              : `Closed on ${new Date(feedback.window_closes_at).toLocaleDateString()}`}
          </p>
        )}
      </div>

      <div className="card-base flex flex-col gap-3">
        <h2 className="section-title">Your rating</h2>
        {feedback.mine.available ? (
          <div className="flex flex-col gap-2">
            <p className="text-2xl font-semibold">{feedback.mine.average?.toFixed(1)} / 5</p>
            {feedback.mine.comments?.map((c, i) => (
              <p className="text-sm text-muted-foreground" key={i}>&ldquo;{c}&rdquo;</p>
            ))}
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">
            Visible once the feedback window closes and at least 3 teammates have rated you.
          </p>
        )}
        {myReport && <ShowcaseToggle optedIn={myReport.showcase_opt_in} workspaceId={id} />}
      </div>

      {feedback.open && (
        <div className="card-base flex flex-col gap-3">
          <h2 className="section-title">Rate your teammates</h2>
          {feedback.rateable.length === 0 && <p className="text-sm text-muted-foreground">No shared work with anyone yet.</p>}
          {feedback.rateable.map((person) => (
            <RateTeammateRow existing={givenByUserId.get(person.user_id) ?? null} key={person.user_id} person={person} workspaceId={id} />
          ))}
        </div>
      )}

      {feedback.all && (
        <div className="card-base flex flex-col gap-3">
          <h2 className="section-title">All ratings (owner)</h2>
          <AllFeedbackTable rows={feedback.all} />
        </div>
      )}

      <p className="text-xs text-muted-foreground">
        Team member outcome reports are on each person&apos;s page — see <Link className="underline" href={ROUTES.workspaceMembers(id)}>Members</Link>.
      </p>
    </div>
  );
}
