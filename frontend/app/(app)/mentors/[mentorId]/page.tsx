import { notFound } from "next/navigation";
import { Star, Users } from "lucide-react";
import { StatCard } from "@/components/shared/stat-card";
import { MentorRatingForm } from "@/components/mentoring/mentor-rating-form";
import { ReportMentorDialog } from "@/components/mentoring/report-mentor-dialog";
import { getMentors } from "@/lib/server/mentoring";
import { getMyFeedback } from "@/lib/server/feedback";

interface Props {
  params: Promise<{ mentorId: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { mentorId } = await params;
  return { title: `Mentor — MindForge`, alternates: { canonical: `/mentors/${mentorId}` } };
}

export default async function MentorProfilePage({ params }: Props) {
  const { mentorId } = await params;

  const [mentors, myFeedback] = await Promise.all([
    getMentors(),
    getMyFeedback("mentor", mentorId).catch(() => null),
  ]);

  const mentor = mentors.find((m) => m.user_id === mentorId);
  if (!mentor) notFound();

  return (
    <main className="page-container-sm py-8">
      <div className="mb-8 flex flex-col gap-2">
        <h1 className="page-title">{mentor.name}</h1>
        <p className="text-muted-foreground">{mentor.email}</p>
      </div>

      <div className="grid-stats mb-8">
        <StatCard icon={Users} label="Mentees" unit="active" value={String(mentor.mentee_count)} />
        <StatCard
          icon={Star}
          label="Rating"
          unit={`${mentor.rating_count} rating${mentor.rating_count === 1 ? "" : "s"}`}
          value={mentor.avg_rating !== null ? mentor.avg_rating.toFixed(1) : "—"}
        />
      </div>

      <div className="flex flex-col gap-6">
        <MentorRatingForm
          initialComment={myFeedback?.comment ?? null}
          initialRating={myFeedback?.rating ?? null}
          mentorId={mentor.user_id}
        />

        <div className="flex justify-start">
          <ReportMentorDialog mentorId={mentor.user_id} />
        </div>
      </div>
    </main>
  );
}
