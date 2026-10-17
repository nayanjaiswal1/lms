import Link from "next/link";
import { FilterChip } from "@/components/courses/filter-chip";
import type { Course } from "@/lib/server/courses";

const DIFFICULTIES = ["beginner", "intermediate", "advanced", "expert"] as const;
const PRICES = ["free", "paid"] as const;
const STATUSES = ["enrolled", "new"] as const;
const SORTS = [
  { value: "newest", label: "Newest" },
  { value: "rating", label: "Top rated" },
  { value: "title", label: "A–Z" },
] as const;

export interface CourseFilterState {
  q: string;
  difficulty: string;
  price: string;
  status: string;
  sort: string;
}

type RawParams = Partial<Record<"q" | "difficulty" | "price" | "status" | "sort", string>>;

const pick = <T extends string>(v: string | undefined, allowed: readonly T[]) =>
  allowed.find((a) => a === v) ?? "";

// Unknown values fall back to "all" so a hand-edited URL never yields an empty page.
export function parseCourseFilters(raw: RawParams): CourseFilterState {
  return {
    q: (raw.q ?? "").trim(),
    difficulty: pick(raw.difficulty, DIFFICULTIES),
    price: pick(raw.price, PRICES),
    status: pick(raw.status, STATUSES),
    sort: pick(raw.sort, SORTS.map((s) => s.value)) || "newest",
  };
}

export function hasActiveFilters(f: CourseFilterState) {
  return Boolean(f.q || f.difficulty || f.price || f.status);
}

export function filterAndSortCourses(
  courses: Course[],
  f: CourseFilterState,
  enrolledIds: Set<string>,
): Course[] {
  const q = f.q.toLowerCase();
  const out = courses.filter(
    (c) =>
      (!q || [c.title, c.description ?? "", c.instructor_name, ...c.tags].some((s) => s.toLowerCase().includes(q))) &&
      (!f.difficulty || c.difficulty === f.difficulty) &&
      (!f.price || (f.price === "free") === c.is_free) &&
      (!f.status || (f.status === "enrolled") === enrolledIds.has(c.id)),
  );
  if (f.sort === "rating") out.sort((a, b) => (b.avg_rating ?? -1) - (a.avg_rating ?? -1) || b.review_count - a.review_count);
  else if (f.sort === "title") out.sort((a, b) => a.title.localeCompare(b.title));
  else out.sort((a, b) => b.created_at.localeCompare(a.created_at));
  return out;
}

function href(base: string, f: CourseFilterState, patch: Partial<CourseFilterState>) {
  const next = { ...f, ...patch };
  const sp = new URLSearchParams();
  if (next.q) sp.set("q", next.q);
  if (next.difficulty) sp.set("difficulty", next.difficulty);
  if (next.price) sp.set("price", next.price);
  if (next.status) sp.set("status", next.status);
  if (next.sort !== "newest") sp.set("sort", next.sort);
  const qs = sp.toString();
  return qs ? `${base}?${qs}` : base;
}

type FilterField = "difficulty" | "price" | "status" | "sort";

export function CourseFilters({
  filters,
  basePath,
  fields = ["difficulty", "price", "status", "sort"],
}: {
  filters: CourseFilterState;
  basePath: string;
  fields?: FilterField[];
}) {
  const f = filters;
  const to = (patch: Partial<CourseFilterState>) => href(basePath, f, patch);
  const all = (key: "difficulty" | "price" | "status", value: string) => ({
    label: "All",
    href: to({ [key]: "" }),
    active: !value,
  });

  const chips: Record<FilterField, React.ReactNode> = {
    difficulty: (
      <FilterChip
        filtered={Boolean(f.difficulty)}
        key="difficulty"
        label="Level"
        options={[
          all("difficulty", f.difficulty),
          ...DIFFICULTIES.map((d) => ({ label: d, href: to({ difficulty: d }), active: f.difficulty === d })),
        ]}
      />
    ),
    price: (
      <FilterChip
        filtered={Boolean(f.price)}
        key="price"
        label="Price"
        options={[all("price", f.price), ...PRICES.map((p) => ({ label: p, href: to({ price: p }), active: f.price === p }))]}
      />
    ),
    status: (
      <FilterChip
        filtered={Boolean(f.status)}
        key="status"
        label="Show"
        options={[
          all("status", f.status),
          { label: "Enrolled", href: to({ status: "enrolled" }), active: f.status === "enrolled" },
          { label: "Not started", href: to({ status: "new" }), active: f.status === "new" },
        ]}
      />
    ),
    sort: (
      <FilterChip
        filtered={f.sort !== "newest"}
        key="sort"
        label="Sort"
        options={SORTS.map((o) => ({ label: o.label, href: to({ sort: o.value }), active: f.sort === o.value }))}
      />
    ),
  };

  return (
    <nav aria-label="Filter courses" className="mb-6 flex flex-wrap items-center gap-2">
      {fields.map((k) => chips[k])}
      {hasActiveFilters(f) && (
        <Link className="px-1 text-xs font-medium text-primary hover:underline" href={basePath} replace scroll={false}>
          Clear
        </Link>
      )}
    </nav>
  );
}
