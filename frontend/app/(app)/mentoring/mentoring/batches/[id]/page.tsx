import { notFound } from "next/navigation";
import Link from "next/link";
import { MessageSquare, BookOpen, Users, BarChart3 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { InvitationList } from "@/components/instructor/batches/invitation-list";
import { BatchProgressTable } from "@/components/instructor/batches/batch-progress-table";
import { BulkInviteForm } from "@/components/instructor/batches/bulk-invite-form";
import {
  getBatch,
  getBatchMembers,
  getBatchInvitations,
  getBatchCourses,
  getBatchProgress,
} from "@/lib/server/batches";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ tab?: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const batch = await getBatch(id).catch(() => null);
  return { title: batch ? `${batch.name} — MindForge` : "Batch — MindForge" };
}

const TABS = [
  { key: "members",     label: "Members",     Icon: Users },
  { key: "courses",     label: "Courses",     Icon: BookOpen },
  { key: "invitations", label: "Invitations", Icon: MessageSquare },
  { key: "progress",    label: "Progress",    Icon: BarChart3 },
] as const;

type Tab = (typeof TABS)[number]["key"];

export default async function MentorBatchDetailPage({ params, searchParams }: Props) {
  const { id } = await params;
  const { tab = "members" } = await searchParams;
  const activeTab = TABS.find((t) => t.key === tab)?.key ?? "members";

  const [batch, members, invitations, courses, progress] = await Promise.all([
    getBatch(id).catch(() => null),
    getBatchMembers(id).catch(() => []),
    getBatchInvitations(id).catch(() => []),
    getBatchCourses(id).catch(() => []),
    getBatchProgress(id).catch(() => []),
  ]);

  if (!batch) notFound();

  return (
    <main className="page-container py-8">
      <div className="page-header">
        <div className="flex items-center gap-3">
          <h1 className="page-title">{batch.name}</h1>
          <Badge variant={batch.status === "active" ? "default" : "secondary"}>
            {batch.status}
          </Badge>
        </div>
        <Button asChild variant="outline">
          <Link href={ROUTES.mentoringBatchChat(id)}>
            <MessageSquare aria-hidden className="mr-2 h-4 w-4" />
            Open chat
          </Link>
        </Button>
      </div>

      {batch.description && (
        <p className="mb-6 text-muted-foreground">{batch.description}</p>
      )}

      <nav className="mb-6 flex gap-1 border-b border-border" aria-label="Batch sections">
        {TABS.map(({ key, label, Icon }) => (
          <Link
            key={key}
            href={`?tab=${key}`}
            className={`flex items-center gap-1.5 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors duration-fast ${
              activeTab === key
                ? "border-primary text-primary"
                : "border-transparent text-muted-foreground hover:text-foreground"
            }`}
            aria-current={activeTab === key ? "page" : undefined}
          >
            <Icon aria-hidden className="h-4 w-4" />
            {label}
          </Link>
        ))}
      </nav>

      <div>
        {activeTab === "members" && (
          <div className="flex flex-col gap-6">
            <div className="table-responsive">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border text-left text-xs text-muted-foreground">
                    <th className="pb-2 font-medium">Name</th>
                    <th className="pb-2 font-medium">Email</th>
                    <th className="pb-2 font-medium">Role</th>
                    <th className="pb-2 font-medium">Joined</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {members.map((m) => (
                    <tr key={m.user_id}>
                      <td className="py-2.5 pr-4 font-medium">{m.name}</td>
                      <td className="py-2.5 pr-4 text-muted-foreground">{m.email}</td>
                      <td className="py-2.5 pr-4 capitalize text-muted-foreground">{m.role ?? "—"}</td>
                      <td className="py-2.5 text-muted-foreground">
                        {m.joined_at ? new Date(m.joined_at).toLocaleDateString() : "—"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {members.length === 0 && (
                <p className="py-4 text-center text-sm text-muted-foreground">No members yet.</p>
              )}
            </div>
          </div>
        )}

        {activeTab === "courses" && (
          <div className="flex flex-col gap-3">
            {courses.length === 0 ? (
              <p className="text-sm text-muted-foreground">No courses assigned yet.</p>
            ) : (
              <ul className="flex flex-col gap-2">
                {courses.map((c) => (
                  <li key={c.course_id} className="card-base flex items-center gap-4 p-4">
                    <div className="flex flex-1 flex-col gap-0.5">
                      <span className="font-medium">{c.title}</span>
                      <span className="text-xs capitalize text-muted-foreground">{c.difficulty}</span>
                    </div>
                    <span className="text-xs text-muted-foreground">
                      {c.assigned_at ? `Assigned ${new Date(c.assigned_at).toLocaleDateString()}` : ""}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}

        {activeTab === "invitations" && (
          <div className="flex flex-col gap-8">
            <div>
              <h2 className="section-title mb-4">Invite students</h2>
              <div className="max-w-lg">
                <BulkInviteForm batchId={id} />
              </div>
            </div>
            <div>
              <h2 className="section-title mb-4">Sent invitations</h2>
              <InvitationList invitations={invitations} />
            </div>
          </div>
        )}

        {activeTab === "progress" && (
          <div>
            <h2 className="section-title mb-4">Student Progress</h2>
            <BatchProgressTable progress={progress} />
          </div>
        )}
      </div>
    </main>
  );
}
