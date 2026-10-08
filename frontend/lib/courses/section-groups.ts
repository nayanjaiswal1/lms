// Nests consecutive course sections that share a group_title (e.g. a
// "Backend" heading grouping "Python"/"Django"/"FastAPI" sections) under one
// group heading. Sections stay a flat, position-ordered list in the DB
// (backend/internal/courses) — this is purely a render-time grouping, so it
// assumes `sections` is already ordered by position like every CourseTree/
// CourseSection API response already is.
interface GroupedSection<T extends { group_title: string | null }> {
  section: T;
  /** Render a group heading (section.group_title) directly above this section. */
  isGroupStart: boolean;
  /** Indent this section as nested under its group heading. */
  isGrouped: boolean;
}

export function groupSections<T extends { group_title: string | null }>(sections: T[]): GroupedSection<T>[] {
  return sections.map((section, i) => ({
    section,
    isGroupStart: section.group_title !== null && sections[i - 1]?.group_title !== section.group_title,
    isGrouped: section.group_title !== null,
  }));
}
