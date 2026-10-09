// GET /api/workspaces/discover row.
export interface DiscoverWorkspace {
  id: string;
  title: string;
  summary: string;
  skills: string[];
  team_size_min: number;
  team_size_max: number;
  interest_deadline: string | null;
  has_applied: boolean;
  created_at: string;
}

// GET /api/my/workspace-interests row.
export interface MyInterest {
  id: string;
  workspace_id: string;
  workspace_title: string;
  workspace_status: string;
  status: string;
  created_at: string;
}
