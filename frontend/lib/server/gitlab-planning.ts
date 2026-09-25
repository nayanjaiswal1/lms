import "server-only";
import { apiGet } from "@/lib/server/api";
import type { AeBoard, AeIssuesPage } from "@/lib/gitlab-planning/types";

export function getPlanningBoard(): Promise<AeBoard> {
  return apiGet<AeBoard>("/api/gitlab/planning/board");
}

export function getPlanningIssues(): Promise<AeIssuesPage> {
  return apiGet<AeIssuesPage>("/api/gitlab/planning/issues");
}
