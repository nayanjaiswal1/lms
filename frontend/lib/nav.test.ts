import { describe, expect, it } from "vite-plus/test";
import { visibleOrgSettingsNav, ORG_SETTINGS_ACCESS } from "@/lib/org-settings-nav";
import { ALL_NAV_ITEMS, withPlatformGroups, LEARN_HUB_GROUPS, MAIN_NAV_GROUPS, TEACHING_HUB_GROUPS, filterNavGroups, type NavGroup } from "@/lib/nav";
import { resolveTerminology, type Terminology } from "@/lib/terminology";

// Copied from backend/internal/authz/testdata/role_matrix.golden.json (the
// authoritative role matrix). Re-copy when that file changes.
const ROLES = {
  viewer: [
    "courses.view",
  ],
  member: [
    "assessments.take",
    "assessments.view_assigned",
    "content.captures",
    "content.certificates",
    "content.diary",
    "content.interview_exp",
    "content.learning_journal",
    "content.sheets",
    "content.srs",
    "content.system_design",
    "content.wiki",
    "courses.enroll",
    "courses.view",
    "mentoring.chat",
    "practice.use",
    "projects.view",
  ],
  instructor: [
    "admin.view_members",
    "assessments.create",
    "assessments.delete",
    "assessments.edit",
    "assessments.manage_batches",
    "assessments.manage_questions",
    "assessments.publish",
    "assessments.take",
    "assessments.view_assigned",
    "assessments.view_results",
    "content.captures",
    "content.certificates",
    "content.diary",
    "content.interview_exp",
    "content.learning_journal",
    "content.sheets",
    "content.srs",
    "content.system_design",
    "content.wiki",
    "courses.create",
    "courses.delete",
    "courses.edit",
    "courses.enroll",
    "courses.publish",
    "courses.view",
    "courses.view_analytics",
    "labauthor.compose",
    "labauthor.manage_blocks",
    "mentoring.assign_tickets",
    "mentoring.chat",
    "mentoring.manage_session_booking",
    "mentoring.verify_mentors",
    "mentoring.view_tickets",
    "messaging.moderate",
    "practice.use",
    "projects.create",
    "projects.manage",
    "projects.view",
    "wiki.create_spaces",
    "wiki.manage_spaces",
  ],
  mentor: [
    "admin.view_members",
    "assessments.take",
    "assessments.view_assigned",
    "assessments.view_results",
    "content.captures",
    "content.certificates",
    "content.diary",
    "content.interview_exp",
    "content.learning_journal",
    "content.sheets",
    "content.srs",
    "content.system_design",
    "content.wiki",
    "courses.enroll",
    "courses.view",
    "mentoring.chat",
    "mentoring.claim_tickets",
    "mentoring.manage_batches",
    "mentoring.view_students",
    "mentoring.view_tickets",
    "messaging.moderate",
    "practice.use",
    "projects.create",
    "projects.view",
    "wiki.manage_spaces",
  ],
  tenant_admin: [
    "admin.manage_members",
    "admin.manage_org",
    "admin.manage_permissions",
    "admin.manage_roles",
    "admin.view_audit_log",
    "admin.view_members",
    "assessments.create",
    "assessments.delete",
    "assessments.edit",
    "assessments.manage_batches",
    "assessments.manage_questions",
    "assessments.publish",
    "assessments.take",
    "assessments.view_assigned",
    "assessments.view_results",
    "calendar.events.manage",
    "content.moderate",
    "content.system_design",
    "content.wiki",
    "courses.create",
    "courses.delete",
    "courses.edit",
    "courses.enroll",
    "courses.publish",
    "courses.view",
    "courses.view_analytics",
    "labauthor.compose",
    "labauthor.manage_blocks",
    "mentoring.assign_tickets",
    "mentoring.chat",
    "mentoring.manage_batches",
    "mentoring.manage_reports",
    "mentoring.manage_session_booking",
    "mentoring.verify_mentors",
    "mentoring.view_students",
    "mentoring.view_tickets",
    "messaging.moderate",
    "payments.manage_coupons",
    "payments.manage_refunds",
    "projects.create",
    "projects.manage",
    "projects.oversee",
    "projects.view",
    "support.manage",
    "wiki.create_spaces",
    "wiki.manage_spaces",
  ],
  support_agent: [
    "support.manage",
  ],
} as const;

type Role = keyof typeof ROLES;

const sidebar = (role: Role, t: Terminology = resolveTerminology(null)) =>
  filterNavGroups(MAIN_NAV_GROUPS, new Set(ROLES[role]), t);
const labels = (groups: NavGroup[]) => groups.flatMap((g) => g.items.map((i) => i.label));
const hub = (role: Role, groups: NavGroup[]) =>
  labels(filterNavGroups(groups, new Set(ROLES[role]), resolveTerminology(null)));

describe("sidebar per role", () => {
  it("viewer: dashboard, help, Learn hub (courses only); no learner tools", () => {
    const l = labels(sidebar("viewer"));
    expect(l).toEqual(["Dashboard", "Help & Support", "Learn"]);
    expect(hub("viewer", LEARN_HUB_GROUPS)).toEqual(["My Courses"]);
  });

  it("member: learner surfaces incl. Mentors directory, no teaching", () => {
    expect(labels(sidebar("member"))).toEqual(["Dashboard", "Calendar", "Help & Support", "Learn", "Mentors"]);
    const l = hub("member", LEARN_HUB_GROUPS);
    expect(l).toEqual(expect.arrayContaining(["Labs", "Roadmap", "Revision", "Saved Highlights", "Workspaces"]));
  });

  it("instructor: Instructor hub + Batches, no Mentors directory, ticket queue via Teach hub", () => {
    const l = labels(sidebar("instructor"));
    expect(l).toEqual(expect.arrayContaining(["Instructor", "Batches", "Learn"]));
    expect(l).not.toContain("Mentors");
    expect(l).not.toContain("Overview");
    expect(l).not.toContain("Roles & Permissions");
    expect(hub("instructor", TEACHING_HUB_GROUPS)).toEqual(
      expect.arrayContaining(["Ticket Queue", "Library", "Lab library", "Create Debug Lab", "Question Bank"]),
    );
  });

  it("mentor: Mentoring group, no Mentors directory, no Instructor hub", () => {
    const groups = sidebar("mentor");
    const l = labels(groups);
    expect(groups.map((g) => g.label)).toContain("Mentoring");
    expect(l).toEqual(expect.arrayContaining(["Overview", "Ticket Queue", "Calendar"]));
    expect(l).not.toContain("Mentors");
    expect(l).not.toContain("Instructor");
    expect(l).not.toContain("Batches");
  });

  it("tenant_admin: admin + support surfaces, no Mentors directory, no learner tools", () => {
    const l = labels(sidebar("tenant_admin"));
    expect(l).toEqual(
      expect.arrayContaining([
        "Calendar", "Instructor", "Batches", "Overview", "Ticket Queue", "Support Queue",
        "Roles & Permissions", "Users", "Coupons", "Content Reports", "Organization Settings",
      ]),
    );
    expect(l).not.toContain("Mentors");
    const learn = hub("tenant_admin", LEARN_HUB_GROUPS);
    // Labs is intentionally visible: courses.edit also opens the labs catalog.
    for (const tool of ["Roadmap", "Revision", "Learning Journal", "Diary", "Captures", "Saved Highlights", "Algorithm Visualizer", "Sheet Tracker", "Interview Experiences"]) {
      expect(learn).not.toContain(tool);
    }
  });

  it("support_agent: Support Queue only, Learn hub hidden", () => {
    expect(labels(sidebar("support_agent"))).toEqual(["Dashboard", "Help & Support", "Support Queue"]);
  });

  it("viewer (courses.view only) sees none of the newly gated items", () => {
    const l = labels(sidebar("viewer"));
    for (const hidden of ["Labs", "Roadmap", "Workspaces", "Mentors", "Calendar"]) expect(l).not.toContain(hidden);
  });
});

describe("filterNavGroups", () => {
  it("hideForPermission accepts an array (hide if ANY held)", () => {
    const items = [{ ...ALL_NAV_ITEMS.dashboard, label: "X", hideForPermission: ["a", "b"] }];
    expect(filterNavGroups([{ items }], new Set(["b"]), resolveTerminology(null)))
      .toEqual([]);
    expect(filterNavGroups([{ items }], new Set(["c"]), resolveTerminology(null)))
      .toHaveLength(1);
  });

  it("applies org terminology to Batches", () => {
    const school = resolveTerminology("school");
    expect(labels(sidebar("instructor", school))).toContain(school.classPlural);
    expect(school.classPlural).not.toBe("Batches");
  });
});

describe("no duplicate hrefs within a surface", () => {
  const surfaces = { sidebar: MAIN_NAV_GROUPS, learn: LEARN_HUB_GROUPS, teach: TEACHING_HUB_GROUPS };
  for (const [name, groups] of Object.entries(surfaces)) {
    it(name, () => {
      const hrefs = groups.flatMap((g) => g.items.map((i) => i.href));
      expect(hrefs.filter((h, i) => hrefs.indexOf(h) !== i)).toEqual([]);
    });
  }
  it("every ungated item is explicitly public", () => {
    const ungated = Object.entries(ALL_NAV_ITEMS).filter(([, i]) => !i.requiredPermission && !i.hub).map(([k]) => k);
    expect(ungated.sort()).toEqual(["dashboard", "support"]);
  });
});

describe("org settings nav", () => {
  const visible = (role: Role) => visibleOrgSettingsNav(new Set(ROLES[role])).map((i) => i.label);

  it("tenant_admin sees every entry", () => {
    expect(visible("tenant_admin")).toEqual([
      "Overview", "Domains", "Authentication", "Integrations", "Labs", "Lab usage", "Warm pools", "Audit Log", "Jobs",
    ]);
  });

  it("mentor, member and instructor see nothing and fail the layout guard", () => {
    for (const role of ["mentor", "member", "instructor"] as const) {
      expect(visible(role)).toEqual([]);
      expect(ORG_SETTINGS_ACCESS.some((c) => (ROLES[role] as readonly string[]).includes(c))).toBe(false);
    }
  });

  it("audit-only holder sees only Audit Log", () => {
    expect(visibleOrgSettingsNav(new Set(["admin.view_audit_log"])).map((i) => i.label)).toEqual(["Audit Log"]);
  });
});

describe("withPlatformGroups", () => {
  const base = sidebar("tenant_admin");
  it("super_admin gets the Platform group appended", () => {
    const out = withPlatformGroups(base, { platform_role: "super_admin" });
    expect(out.map((g) => g.label)).toContain("Platform");
    expect(out).toHaveLength(base.length + 1);
  });
  it("other users and anonymous get the groups unchanged", () => {
    for (const u of [{ platform_role: null }, { platform_role: "user" }, {}, null, undefined]) {
      expect(withPlatformGroups(base, u)).toBe(base);
    }
  });
});
