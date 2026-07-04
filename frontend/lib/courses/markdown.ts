import { marked } from "marked";
import type { ContentBlock } from "@/lib/courses/draft-types";

function youtubeEmbedUrl(videoId: string): string {
  return `https://www.youtube-nocookie.com/embed/${videoId}?rel=0&modestbranding=1`;
}

export interface TocEntry {
  id: string;
  text: string;
  level: 2 | 3;
}

interface ParsedModuleContent {
  html: string;
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
    case "image": {
      if (!block.url) return "";
      const caption = block.caption ? `<figcaption>${escapeHtml(block.caption)}</figcaption>` : "";
      return `<figure><img src="${escapeHtml(block.url)}" alt="${escapeHtml(block.alt)}" loading="lazy" />${caption}</figure>`;
    }
    case "code":
      return `<pre><code class="language-${escapeHtml(block.language)}">${escapeHtml(block.code)}</code></pre>`;
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
  }
}

function addHeadingIds(rawHtml: string): ParsedModuleContent {
  const toc: TocEntry[] = [];
  const seen = new Map<string, number>();

  const html = rawHtml.replace(/<h([23])>(.*?)<\/h\1>/g, (_match, level: string, inner: string) => {
    const text = inner.replace(/<[^>]+>/g, "");
    const base = slugify(text);
    const count = seen.get(base) ?? 0;
    seen.set(base, count + 1);
    const id = count > 0 ? `${base}-${count}` : base;

    toc.push({ id, text, level: Number(level) as 2 | 3 });
    return `<h${level} id="${id}">${inner}</h${level}>`;
  });

  return { html, toc };
}

// Modules built with the block-based wizard store `content_body` as a JSON
// array of ContentBlock. Modules created via the plain-text editor store raw
// markdown instead. Detect which shape we have and render accordingly, then
// derive an anchor-linkable TOC from the h2/h3 headings so the content body
// and the "on this page" rail render off a single source.
export function renderModuleMarkdown(body: string): ParsedModuleContent {
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    parsed = null;
  }

  const rawHtml = Array.isArray(parsed)
    ? (parsed as ContentBlock[]).map(blockToHtml).join("\n")
    : (marked.parse(body, { async: false, gfm: true }) as string);

  return addHeadingIds(rawHtml);
}
