export type OrgStatus =
  | "pending_verification"
  | "onboarding"
  | "active"
  | "suspended"
  | "archived";

export type OrgRole = "owner" | "admin" | "mentor" | "instructor" | "learner";

export type MemberStatus = "active" | "suspended" | "removed";

export interface Org {
  id: string;
  slug: string;
  name: string;
  logo_url: string | null;
  description: string | null;
  status: OrgStatus;
  seat_limit: number | null;
  active_member_count: number;
  onboarding_step: number;
  onboarding_completed_at: string | null;
  activated_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface OrgSummary {
  id: string;
  slug: string;
  name: string;
  role: OrgRole;
}

export interface Member {
  id: string;
  user_id: string;
  name: string;
  email: string;
  avatar_url: string | null;
  role: OrgRole;
  status: MemberStatus;
  joined_at: string;
}

export interface MemberPage {
  members: Member[];
  next_cursor?: string;
}

export interface Invite {
  id: string;
  org_id: string;
  email: string;
  role: OrgRole;
  invited_by: string;
  expires_at: string;
  accepted_at: string | null;
  revoked_at: string | null;
  created_at: string;
}

export interface InvitePage {
  invites: Invite[];
  next_cursor?: string;
}

export interface Domain {
  id: string;
  org_id: string;
  domain: string;
  verified: boolean;
  verification_method: string | null;
  verification_token: string;
  verified_at: string | null;
  auto_join_enabled: boolean;
  created_at: string;
}

export interface AuditLog {
  id: string;
  org_id: string;
  actor_user_id: string | null;
  action: string;
  target_type: string;
  target_id: string | null;
  before_state: unknown;
  after_state: unknown;
  ip_address: string | null;
  created_at: string;
}

export interface AuditLogPage {
  logs: AuditLog[];
  next_cursor?: string;
}

export interface OrgAuthConfig {
  org_id: string;
  sso_enabled: boolean;
  sso_provider: string | null;
  password_policy: Record<string, unknown>;
  allowed_domains: string[];
}

export interface OnboardingState {
  step: number;
  onboarding_completed_at: string | null;
  org: Org | null;
  auth_config: OrgAuthConfig | null;
}
