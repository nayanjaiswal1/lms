// ─── Block types ─────────────────────────────────────────────────────────────

export type HeadingLevel   = "h2" | "h3";
export type CalloutVariant = "info" | "warning" | "tip" | "danger";

export interface ParagraphBlock { id: string; type: "paragraph"; text: string }
export interface HeadingBlock   { id: string; type: "heading";   level: HeadingLevel; text: string }
export interface ImageBlock     { id: string; type: "image";     url: string; previewUrl?: string; alt: string; caption: string }
export interface CodeBlock      { id: string; type: "code";      language: string; code: string }
export interface YouTubeBlock   { id: string; type: "youtube";   videoId: string; caption: string }
export interface VideoBlock     { id: string; type: "video";     url: string; storageKey: string; previewUrl?: string; title: string }
export interface PdfBlock       { id: string; type: "pdf";       url: string; previewUrl?: string; title: string }
export interface DownloadBlock  { id: string; type: "download";  url: string; previewUrl?: string; filename: string; description: string }
export interface DividerBlock   { id: string; type: "divider" }
export interface CalloutBlock   { id: string; type: "callout";   variant: CalloutVariant; text: string }

export type ContentBlock =
  | ParagraphBlock | HeadingBlock | ImageBlock  | CodeBlock
  | YouTubeBlock   | VideoBlock   | PdfBlock    | DownloadBlock
  | DividerBlock   | CalloutBlock;

// ─── Draft structures ─────────────────────────────────────────────────────────

export interface DraftModule {
  localId:           string;
  id?:               string; // present when editing an existing module
  title:             string;
  type:              string;
  estimated_minutes: number;
  is_free_preview:   boolean;
  blocks:            ContentBlock[];
}

export interface DraftSection {
  localId: string;
  id?:     string; // present when editing an existing section
  title:   string;
  modules: DraftModule[];
}

export interface CourseInfo {
  title:       string;
  description: string;
  cover_url:   string;
  difficulty:  string;
  tags:        string[];
  is_free:     boolean;
}

export interface CourseDraft {
  info:     CourseInfo;
  sections: DraftSection[];
  status:   "draft" | "published";
}

// ─── Factories ────────────────────────────────────────────────────────────────

const uid = () => crypto.randomUUID();

export function makeSection(title = "New Section"): DraftSection {
  return { localId: uid(), title, modules: [] };
}

export function makeModule(type = "notes"): DraftModule {
  return { localId: uid(), title: "Untitled lesson", type, estimated_minutes: 5, is_free_preview: false, blocks: [] };
}

export function makeBlock(type: ContentBlock["type"]): ContentBlock {
  const id = uid();
  switch (type) {
    case "paragraph": return { id, type: "paragraph", text: "" };
    case "heading":   return { id, type: "heading",   level: "h2", text: "" };
    case "image":     return { id, type: "image",     url: "", alt: "", caption: "" };
    case "code":      return { id, type: "code",      language: "javascript", code: "" };
    case "youtube":   return { id, type: "youtube",   videoId: "", caption: "" };
    case "video":     return { id, type: "video",     url: "", storageKey: "", title: "", privacy: "enrolled" } as VideoBlock;
    case "pdf":       return { id, type: "pdf",       url: "", title: "" };
    case "download":  return { id, type: "download",  url: "", filename: "", description: "" };
    case "divider":   return { id, type: "divider" };
    case "callout":   return { id, type: "callout",   variant: "info", text: "" };
  }
}

export const EMPTY_DRAFT: CourseDraft = {
  info: { title: "", description: "", cover_url: "", difficulty: "beginner", tags: [], is_free: true },
  sections: [],
  status: "draft",
};

// ─── Load an existing course into a draft (edit mode) ─────────────────────────

// Modules created via the block-based wizard store `content_body` as a JSON
// array of blocks. Modules created via the plain-text ModuleEditor store raw
// text instead — fall back to a single paragraph block so that content is
// never silently dropped when opened in the wizard.
export function parseBlocks(contentBody: string | null): ContentBlock[] {
  if (!contentBody) return [];
  try {
    const parsed: unknown = JSON.parse(contentBody);
    if (Array.isArray(parsed)) return parsed as ContentBlock[];
  } catch {
    // not JSON — fall through to plain-text handling
  }
  return [{ id: uid(), type: "paragraph", text: contentBody }];
}

export function courseTreeToDraft(tree: {
  title: string;
  description: string | null;
  cover_url: string | null;
  difficulty: string;
  tags: string[];
  is_free: boolean;
  status: string;
  sections: {
    id: string;
    title: string;
    modules: {
      id: string;
      title: string;
      type: string;
      estimated_minutes: number | null;
      is_free_preview: boolean;
      content_body: string | null;
    }[];
  }[];
}): CourseDraft {
  return {
    info: {
      title:       tree.title,
      description: tree.description ?? "",
      cover_url:   tree.cover_url ?? "",
      difficulty:  tree.difficulty,
      tags:        tree.tags ?? [],
      is_free:     tree.is_free,
    },
    sections: tree.sections.map((section) => ({
      localId: uid(),
      id:      section.id,
      title:   section.title,
      modules: section.modules.map((mod) => ({
        localId:           uid(),
        id:                mod.id,
        title:             mod.title,
        type:              mod.type,
        estimated_minutes: mod.estimated_minutes ?? 5,
        is_free_preview:   mod.is_free_preview,
        blocks:            parseBlocks(mod.content_body),
      })),
    })),
    status: tree.status === "published" ? "published" : "draft",
  };
}
