import type { Metadata } from "next";

import { DashboardFilters } from "@/components/workspace/dashboard/dashboard-filters";
import { DashboardHealthBadge } from "@/components/workspace/dashboard/dashboard-health-badge";
import { DeliverySection } from "@/components/workspace/dashboard/delivery-section";
import { NeedsAttentionList } from "@/components/workspace/dashboard/needs-attention-list";
import { PlanTree } from "@/components/workspace/dashboard/plan-tree";
import { QualitySection } from "@/components/workspace/dashboard/quality-section";
import { CSVExportButtons } from "@/components/workspace/dashboard/csv-export-buttons";
import { ReleaseMetricsSection } from "@/components/workspace/dashboard/release-metrics-section";
import { WorkspaceGitlabSection } from "@/components/workspace/gitlab/workspace-gitlab-section";
import { TeamSection } from "@/components/workspace/dashboard/team-section";
import { WeeklySummaryCard } from "@/components/workspace/dashboard/weekly-summary-card";
import { getWorkspaceDashboard } from "@/lib/workspace/phase4-server";
import { getWorkspace, listWorkspaceMembers, listWorkspaceTracks } from "@/lib/workspace/server";
import { PROJECT_STATUS_LABEL } from "@/lib/workspace/roles";

export const metadata: Metadata = {
  title: "Dashboard",
};

interface PageProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ from?: string; to?: string; track?: string; user?: string }>;
}

export default async function WorkspaceDashboardPage({ params, searchParams }: PageProps) {
  const { id } = await params;
  const sp = await searchParams;

  const [workspace, tracks, members, dashboard] = await Promise.all([
    getWorkspace(id),
    listWorkspaceTracks(id),
    listWorkspaceMembers(id),
    getWorkspaceDashboard(id, { from: sp.from, to: sp.to, track: sp.track, user: sp.user }),
  ]);

  const isManagerPlus = workspace.my_role === "owner" || workspace.my_role === "manager" || workspace.is_overseer;
  const isTrackLead = workspace.led_track_ids.length > 0;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <h1 className="page-title">Dashboard</h1>
          <DashboardHealthBadge health={dashboard.header.health} />
          <span className="text-sm text-muted-foreground">{PROJECT_STATUS_LABEL[dashboard.header.status]}</span>
        </div>
        <DashboardFilters
          members={members}
          showTrackFilter={isManagerPlus}
          showUserFilter={isManagerPlus || isTrackLead}
          tracks={tracks}
        />
      </div>

      {isManagerPlus && <CSVExportButtons workspaceId={id} />}

      <NeedsAttentionList needsAttention={dashboard.needs_attention} workspaceId={id} />

      {isManagerPlus && <WeeklySummaryCard initial={dashboard.ai_summary} workspaceId={id} />}

      {dashboard.release && <ReleaseMetricsSection release={dashboard.release} />}

      <div className="grid-responsive-2 gap-4">
        <DeliverySection delivery={dashboard.delivery} />
        <QualitySection quality={dashboard.quality} />
      </div>

      <TeamSection people={dashboard.people} tracks={dashboard.tracks} />

      {workspace.cohort_id && (workspace.gitlab_web_url || workspace.provision_status) && (
        <WorkspaceGitlabSection workspaceId={id} workspaceTitle={workspace.title} />
      )}

      <div className="card-base flex flex-col gap-3">
        <h2 className="section-title">Plan</h2>
        <PlanTree nodes={dashboard.plan_tree} workspaceId={id} />
      </div>
    </div>
  );
}
