import { marked, type Token, type Tokens } from "marked";
import type { ContentBlock } from "@/lib/courses/draft-types";

function youtubeEmbedUrl(videoId: string): string {
  return `https://www.youtube-nocookie.com/embed/${videoId}?rel=0&modestbranding=1`;
}

export interface TocEntry {
  id: string;
  text: string;
  level: 2 | 3;
}

// Lesson content split at the two seams the reader UI cares about: code
// blocks (live Run button) and images (pulled into the side diagram panel).
// Everything else batches into opaque html segments.
export type Segment =
  | { type: "html"; html: string }
  | { type: "code"; language: string; code: string }
  | { type: "image"; src: string; alt: string; caption?: string; headingId: string | null }
  | { type: "lab-task"; position: number };

export interface LessonImage {
  src: string;
  alt: string;
  caption?: string;
  headingId: string | null;
}

interface ParsedModuleContent {
  segments: Segment[];
  toc: TocEntry[];
}

function slugify(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// ─── Wizard blocks → segments ────────────────────────────────────────────────

function blockToHtml(block: ContentBlock): string {
  switch (block.type) {
    case "paragraph":
      return block.text ? (marked.parse(block.text, { async: false, gfm: true }) as string) : "";
    case "heading": {
      const inline = marked.parseInline(block.text, { async: false, gfm: true }) as string;
      return `<${block.level}>${inline}</${block.level}>`;
    }
    case "callout": {
      const inline = marked.parse(block.text, { async: false, gfm: true }) as string;
      return `<div class="callout callout-${block.variant}">${inline}</div>`;
    }
    case "youtube": {
      if (!block.videoId) return "";
      const caption = block.caption ? `<p class="media-caption">${escapeHtml(block.caption)}</p>` : "";
      return `<div class="media-embed"><iframe src="${escapeHtml(youtubeEmbedUrl(block.videoId))}" title="YouTube video" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe></div>${caption}`;
    }
    case "video": {
      if (!block.url) return "";
      const caption = block.title ? `<p class="media-caption">${escapeHtml(block.title)}</p>` : "";
      return `<div class="media-embed"><video src="${escapeHtml(block.url)}" controls></video></div>${caption}`;
    }
    case "pdf": {
      if (!block.url) return "";
      return `<a class="file-card" href="${escapeHtml(block.url)}" target="_blank" rel="noopener noreferrer">${escapeHtml(block.title || "View PDF")}</a>`;
    }
    case "download": {
      if (!block.url) return "";
      const description = block.description ? ` — ${escapeHtml(block.description)}` : "";
      return `<a class="file-card" href="${escapeHtml(block.url)}" download>${escapeHtml(block.filename || "Download")}${description}</a>`;
    }
    case "divider":
      return "<hr />";
    // code/image are handled as dedicated segments before this is called
    case "code":
    case "image":
      return "";
  }
}

function blocksToSegments(blocks: ContentBlock[]): Segment[] {
  const segments: Segment[] = [];
  let htmlBatch: string[] = [];

  const flush = () => {
    if (htmlBatch.length === 0) return;
    segments.push({ type: "html", html: htmlBatch.join("\n") });
    htmlBatch = [];
  };

  for (const block of blocks) {
    if (block.type === "code") {
      flush();
      segments.push({ type: "code", language: block.language, code: block.code });
    } else if (block.type === "image") {
      if (!block.url) continue;
      flush();
      segments.push({
        type: "image",
        src: block.url,
        alt: block.alt,
        caption: block.caption || undefined,
        headingId: null,
      });
    } else {
      const html = blockToHtml(block);
      if (html) htmlBatch.push(html);
    }
  }
  flush();
  return segments;
}

// ─── Raw markdown → segments ─────────────────────────────────────────────────

// A paragraph whose only meaningful inline token is an image is a standalone
// figure — pull it out as an image segment. Inline images inside running text
// stay in the html flow untouched.
function soleImage(token: Token): Tokens.Image | null {
  if (token.type !== "paragraph") return null;
  const meaningful = (token.tokens ?? []).filter(
    (t) => !(t.type === "text" && t.raw.trim() === ""),
  );
  if (meaningful.length === 1 && meaningful[0].type === "image") {
    return meaningful[0] as Tokens.Image;
  }
  return null;
}

function markdownToSegments(body: string): Segment[] {
  const tokens = marked.lexer(body, { gfm: true });
  const segments: Segment[] = [];
  let batch: Token[] = [];

  const flush = () => {
    if (batch.length === 0) return;
    segments.push({ type: "html", html: marked.parser(batch, { async: false, gfm: true }) as string });
    batch = [];
  };

  for (const token of tokens) {
    if (token.type === "code") {
      flush();
      segments.push({ type: "code", language: (token.lang as string | undefined) ?? "", code: token.text });
      continue;
    }
    if (token.type === "paragraph") {
      const match = token.raw.trim().match(/^\[\[lab-task:(\d+)\]\]$/);
      if (match) {
        flush();
        segments.push({ type: "lab-task", position: Number(match[1]) });
        continue;
      }
    }
    const image = soleImage(token);
    if (image) {
      flush();
      segments.push({
        type: "image",
        src: image.href,
        alt: image.text,
        caption: image.title ?? undefined,
        headingId: null,
      });
      continue;
    }
    batch.push(token);
  }
  flush();
  return segments;
}

// ─── Heading ids + TOC + image→section association ───────────────────────────

// Walks segments in document order: gives every h2/h3 a slug id (deduped
// across the whole lesson), collects the TOC, and stamps each image segment
// with the id of the heading it appears under.
function annotate(segments: Segment[]): ParsedModuleContent {
  const toc: TocEntry[] = [];
  const seen = new Map<string, number>();
  let lastHeadingId: string | null = null;

  const annotated = segments.map((segment): Segment => {
    if (segment.type === "image") {
      return { ...segment, headingId: lastHeadingId };
    }
    if (segment.type !== "html") return segment;

    const html = segment.html.replace(/<h([23])>(.*?)<\/h\1>/g, (_match, level: string, inner: string) => {
      const text = inner.replace(/<[^>]+>/g, "");
      const base = slugify(text);
      const count = seen.get(base) ?? 0;
      seen.set(base, count + 1);
      const id = count > 0 ? `${base}-${count}` : base;

      toc.push({ id, text, level: Number(level) as 2 | 3 });
      lastHeadingId = id;
      return `<h${level} id="${id}">${inner}</h${level}>`;
    });

    return { type: "html", html };
  });

  return { segments: annotated, toc };
}

// Modules built with the block-based wizard store `content_body` as a JSON
// array of ContentBlock. Modules created via the plain-text editor store raw
// markdown instead. Detect which shape we have, split it into segments (html /
// code / image), then derive an anchor-linkable TOC from the h2/h3 headings so
// the content body and the "on this page" rail render off a single source.
export function renderModuleMarkdown(body: string): ParsedModuleContent {
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    parsed = null;
  }

  const segments = Array.isArray(parsed)
    ? blocksToSegments(parsed as ContentBlock[])
    : markdownToSegments(body);

  return annotate(segments);
}
