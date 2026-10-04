import type { CourseTree } from "@/lib/server/courses";

// Lesson markdown can be tens of KB per module; the sidebar only needs
// titles/types. Passing the full tree into client components serialized every
// lesson body into the RSC payload on each navigation (~300 KB for a 50-lesson course).
export function withoutBodies(tree: CourseTree): CourseTree {
  return {
    ...tree,
    sections: tree.sections.map((s) => ({
      ...s,
      modules: s.modules.map((m) => ({ ...m, content_body: null })),
    })),
  };
}
