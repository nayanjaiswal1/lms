import sanitizeHtml from "sanitize-html";

// Lesson HTML comes from author-controlled markdown (raw HTML passes through
// marked untouched) and from block templates, then is injected with
// dangerouslySetInnerHTML for every learner and for anonymous public courses.
// Everything goes through this allowlist first: no script, no event handlers,
// no javascript: URLs, and iframes only for the YouTube embed the block
// templates emit.

const YOUTUBE_EMBED_PREFIX = "https://www.youtube-nocookie.com/embed/";

const OPTIONS: sanitizeHtml.IOptions = {
  allowedTags: [
    ...sanitizeHtml.defaults.allowedTags,
    "img", "h1", "h2", "h3", "h4", "h5", "h6", "details", "summary", "kbd", "mark",
    "sup", "sub", "del", "figure", "figcaption", "video", "iframe", "u", "s",
  ],
  allowedAttributes: {
    a: ["href", "name", "title", "class", "target", "rel", "download"],
    img: ["src", "alt", "title", "width", "height", "loading"],
    video: ["src", "controls"],
    iframe: ["src", "title", "allow", "allowfullscreen"],
    th: ["align", "colspan", "rowspan"],
    td: ["align", "colspan", "rowspan"],
    code: ["class"],
    "*": ["class", "id"],
  },
  allowedSchemes: ["http", "https", "mailto"],
  allowedSchemesByTag: { img: ["http", "https"], video: ["http", "https"] },
  allowProtocolRelative: false,
  allowedIframeHostnames: ["www.youtube-nocookie.com"],
  exclusiveFilter: (frame) =>
    frame.tag === "iframe" && !(frame.attribs.src ?? "").startsWith(YOUTUBE_EMBED_PREFIX),
};

export function sanitizeLessonHtml(html: string): string {
  return sanitizeHtml(html, OPTIONS);
}
