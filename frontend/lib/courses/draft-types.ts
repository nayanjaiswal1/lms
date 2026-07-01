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
  title:             string;
  type:              string;
  estimated_minutes: number;
  is_free_preview:   boolean;
  blocks:            ContentBlock[];
}

export interface DraftSection {
  localId: string;
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
