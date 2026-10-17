import { describe, expect, it } from "vite-plus/test";
import { availablePersonas, resolvePersona } from "@/lib/auth/personas";

// Only the persona marker codes per role are copied from
// backend/internal/authz/testdata/role_matrix.golden.json (the authoritative
// role matrix); the rest of each role's list is irrelevant here. Re-copy when
// that file changes.
const ROLES = {
  viewer: ["courses.view"],
  member: ["courses.view", "courses.enroll", "practice.use", "mentoring.chat"],
  instructor: ["courses.view", "courses.create", "mentoring.view_tickets", "practice.use"],
  mentor: ["courses.view", "mentoring.manage_batches", "mentoring.view_students", "practice.use"],
  tenant_admin: ["admin.manage_org", "courses.create", "mentoring.manage_batches", "courses.view"],
  support_agent: ["courses.view", "support.manage"],
} as const;

describe("availablePersonas", () => {
  it("is empty for viewer", () => expect(availablePersonas(ROLES.viewer)).toEqual([]));
  it("member -> learn", () => expect(availablePersonas(ROLES.member)).toEqual(["learn"]));
  it("instructor -> teach, learn", () => expect(availablePersonas(ROLES.instructor)).toEqual(["teach", "learn"]));
  it("mentor -> mentor, learn", () => expect(availablePersonas(ROLES.mentor)).toEqual(["mentor", "learn"]));
  it("tenant_admin -> admin, teach, mentor", () =>
    expect(availablePersonas(ROLES.tenant_admin)).toEqual(["admin", "teach", "mentor"]));
  it("support_agent -> support", () => expect(availablePersonas(ROLES.support_agent)).toEqual(["support"]));
});

describe("resolvePersona", () => {
  it("viewer resolves to read-only viewer", () => expect(resolvePersona(ROLES.viewer)).toBe("viewer"));
  it("picks highest available", () => {
    expect(resolvePersona(ROLES.member)).toBe("learn");
    expect(resolvePersona(ROLES.instructor)).toBe("teach");
    expect(resolvePersona(ROLES.mentor)).toBe("mentor");
    expect(resolvePersona(ROLES.tenant_admin)).toBe("admin");
    expect(resolvePersona(ROLES.support_agent)).toBe("support");
  });
  it("honours a valid preferred persona", () => {
    expect(resolvePersona(ROLES.tenant_admin, "mentor")).toBe("mentor");
    expect(resolvePersona(ROLES.instructor, "learn")).toBe("learn");
  });
  it("falls back when preferred is unavailable or invalid", () => {
    expect(resolvePersona(ROLES.member, "admin")).toBe("learn");
    expect(resolvePersona(ROLES.member, "bogus")).toBe("learn");
    expect(resolvePersona(ROLES.viewer, "learn")).toBe("viewer");
    expect(resolvePersona(ROLES.tenant_admin, null)).toBe("admin");
  });
});
