import assert from "node:assert/strict";
import { test } from "node:test";
import { withoutBodies } from "./slim-tree.ts";

test("withoutBodies nulls every content_body and keeps other fields", () => {
  const tree = {
    id: "c1",
    sections: [{ id: "s1", modules: [{ id: "m1", title: "T", content_body: "# big" }] }],
  } as never;
  const out = withoutBodies(tree) as never as {
    id: string;
    sections: { modules: { title: string; content_body: unknown }[] }[];
  };
  assert.equal(out.id, "c1");
  assert.equal(out.sections[0].modules[0].title, "T");
  assert.equal(out.sections[0].modules[0].content_body, null);
});
