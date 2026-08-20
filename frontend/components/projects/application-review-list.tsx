"use client";

import * as React from "react";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { parseAsStringEnum, useQueryState } from "nuqs";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { UserLink } from "@/components/shared/user-link";
import { reviewApplicationAction } from "@/app/(app)/projects/actions";
import { APPLICATION_STATUS_LABEL, APPLICATION_STATUS_VARIANT } from "@/lib/constants";
import type { ApplicationStatus, ProjectApplication } from "@/lib/projects/types";

interface ApplicationReviewListProps {
  applications: ProjectApplication[];
  requirementId: string;
}

// "all" plus every real ApplicationStatus — URL-driven so a shared link lands
// on the same filter, same convention as assignment-tabs.tsx's "tab" param.
const FILTER_VALUES = ["all", "submitted", "shortlisted", "selected", "rejected"] as const;
type Filter = (typeof FILTER_VALUES)[number];

export function ApplicationReviewList({ applications, requirementId }: ApplicationReviewListProps) {
  const router = useRouter();
  const [filter, setFilter] = useQueryState("status", parseAsStringEnum<Filter>([...FILTER_VALUES]).withDefault("all"));
  const [pendingId, setPendingId] = React.useState<string | null>(null);
  const [rejectTarget, setRejectTarget] = React.useState<ProjectApplication | null>(null);

  async function handleReview(applicationId: string, status: ApplicationStatus) {
    setPendingId(applicationId);
    const result = await reviewApplicationAction(applicationId, requirementId, status);
    setPendingId(null);
    setRejectTarget(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`Application marked ${status}.`);
    router.refresh();
  }

  const counts = React.useMemo(() => {
    const out: Record<Filter, number> = { all: applications.length, submitted: 0, shortlisted: 0, selected: 0, rejected: 0 };
    for (const app of applications) out[app.status]++;
    return out;
  }, [applications]);

  const visible = filter === "all" ? applications : applications.filter((a) => a.status === filter);

  return (
    <Tabs value={filter} onValueChange={(next) => void setFilter(next as Filter)}>
      <TabsList>
        {FILTER_VALUES.map((value) => (
          <TabsTrigger key={value} value={value}>
            {value === "all" ? "All" : (APPLICATION_STATUS_LABEL[value] ?? value)} ({counts[value]})
          </TabsTrigger>
        ))}
      </TabsList>

      <TabsContent className="mt-4" value={filter}>
        {visible.length === 0 ? (
          <div className="empty-state py-12">
            <p className="font-medium text-muted-foreground">
              {filter === "all" ? "No applications yet." : `No ${APPLICATION_STATUS_LABEL[filter] ?? filter} applications.`}
            </p>
          </div>
        ) : (
          <ul className="divide-y divide-border rounded-md border border-border">
            {visible.map((app) => (
              <li className="flex flex-col gap-2 px-4 py-3" key={app.id}>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="min-w-0">
                    <UserLink className="truncate font-medium hover:underline" userId={app.user_id}>
                      {app.name}
                    </UserLink>
                    <p className="truncate text-xs text-muted-foreground">{app.email}</p>
                  </div>
                  <div className="flex items-center gap-1.5">
                    {app.ai_score !== undefined && (
                      <Badge className="text-ai" variant="outline">
                        {Math.round(app.ai_score)}/100
                      </Badge>
                    )}
                    <Badge variant={APPLICATION_STATUS_VARIANT[app.status] ?? "outline"}>
                      {APPLICATION_STATUS_LABEL[app.status] ?? app.status}
                    </Badge>
                  </div>
                </div>
                {app.motivation && <p className="text-sm text-muted-foreground">{app.motivation}</p>}
                {app.ai_rationale && <p className="ai-surface rounded-md p-2 text-xs">{app.ai_rationale}</p>}
                {(app.status === "submitted" || app.status === "shortlisted") && (
                  <div className="flex flex-wrap gap-2">
                    {app.status === "submitted" && (
                      <Button
                        disabled={pendingId === app.id}
                        size="sm"
                        variant="outline"
                        onClick={() => handleReview(app.id, "shortlisted")}
                      >
                        Shortlist
                      </Button>
                    )}
                    <Button disabled={pendingId === app.id} size="sm" onClick={() => handleReview(app.id, "selected")}>
                      Select
                    </Button>
                    <Button
                      disabled={pendingId === app.id}
                      size="sm"
                      variant="outline"
                      onClick={() => setRejectTarget(app)}
                    >
                      Reject
                    </Button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </TabsContent>

      <ConfirmDialog
        destructive
        confirmLabel="Reject"
        description={rejectTarget ? `${rejectTarget.name} will be notified their application to this requirement was not accepted.` : ""}
        open={rejectTarget !== null}
        pending={rejectTarget !== null && pendingId === rejectTarget.id}
        title={rejectTarget ? `Reject ${rejectTarget.name}'s application?` : "Reject application?"}
        onConfirm={() => rejectTarget && handleReview(rejectTarget.id, "rejected")}
        onOpenChange={(open) => !open && setRejectTarget(null)}
      />
    </Tabs>
  );
}
