import { describe, expect, it } from "vite-plus/test";
import { containerHours } from "./usage-format";

describe("containerHours", () => {
  it("converts seconds to one-decimal hours", () => {
    expect(containerHours(0)).toBe("0.0");
    expect(containerHours(5400)).toBe("1.5");
    expect(containerHours(3600 * 12 + 1000)).toBe("12.3");
  });
  it("clamps negatives", () => {
    expect(containerHours(-5)).toBe("0.0");
  });
});
