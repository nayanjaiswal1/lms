// Types mirroring backend/internal/library — see docs/courses.md "Course
// library ('Add from library')".

export type LibraryKind = "lab" | "quiz" | "notes";

export interface LibraryItem {
  kind: LibraryKind;
  id: string;
  title: string;
  description?: string;
  mode: "reference" | "copy";
  platform: boolean;
  created_at: string;
}

export interface LibraryItemPage {
  items: LibraryItem[];
  next_cursor?: string;
}

export interface LibraryListFilter {
  types?: LibraryKind[];
  q?: string;
  cursor?: string;
}

export interface AttachLibraryItemInput {
  kind: LibraryKind;
  item_id: string;
  position?: number;
  title?: string;
  is_required?: boolean;
}
