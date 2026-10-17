import { describe, expect, it } from "vite-plus/test";
import { countPendingInvites } from "./pending-invites";

describe("countPendingInvites", () => {
  it("excludes accepted, revoked and expired", () => {
    const now = Date.parse("2026-01-10T00:00:00Z");
    const future = "2026-01-20T00:00:00Z";
    expect(
      countPendingInvites(
        [
          { expires_at: future },
          { expires_at: future, accepted_at: "2026-01-02T00:00:00Z" },
          { expires_at: future, revoked_at: "2026-01-02T00:00:00Z" },
          { expires_at: "2026-01-01T00:00:00Z" },
        ],
        now,
      ),
    ).toBe(1);
  });
});
