import ReactMarkdown, { type Components } from "react-markdown";
import remarkGfm from "remark-gfm";

import { cn } from "@/lib/utils";

// Bare h1–h6/p/blockquote/pre/code/table are styled at full lesson-page
// scale in app/globals.css's @layer base (frontend/CLAUDE.md: "never
// re-style them per component"). A sticky-note-sized journal card can't use
// those elements as-is, so every node gets its own small renderer here
// instead of fighting the base styles with descendant-selector overrides.
const components: Components = {
  h1: ({ children }) => <p className="mt-3 text-sm font-semibold text-foreground first:mt-0">{children}</p>,
  h2: ({ children }) => <p className="mt-3 text-sm font-semibold text-foreground first:mt-0">{children}</p>,
  h3: ({ children }) => <p className="mt-2 text-sm font-semibold text-foreground first:mt-0">{children}</p>,
  p: ({ children }) => <p className="mt-2 text-sm leading-relaxed text-muted-foreground first:mt-0">{children}</p>,
  strong: ({ children }) => <strong className="font-semibold text-foreground">{children}</strong>,
  em: ({ children }) => <em className="italic">{children}</em>,
  ul: ({ children }) => (
    <ul className="mt-2 list-disc space-y-1 pl-5 text-sm leading-relaxed text-muted-foreground first:mt-0">{children}</ul>
  ),
  ol: ({ children }) => (
    <ol className="mt-2 list-decimal space-y-1 pl-5 text-sm leading-relaxed text-muted-foreground first:mt-0">{children}</ol>
  ),
  li: ({ children }) => <li>{children}</li>,
  blockquote: ({ children }) => (
    <blockquote className="mt-2 border-l-2 border-border pl-3 text-sm italic text-muted-foreground first:mt-0">
      {children}
    </blockquote>
  ),
  code: ({ children, className }) => (
    <code className={cn("rounded-sm bg-muted px-1 py-0.5 font-mono text-xs text-foreground", className)}>
      {children}
    </code>
  ),
  pre: ({ children }) => (
    <pre className="mt-2 overflow-x-auto rounded-md bg-muted p-3 font-mono text-xs first:mt-0 [&_code]:bg-transparent [&_code]:p-0">
      {children}
    </pre>
  ),
  a: ({ children, href }) => (
    <a
      className="text-foreground underline underline-offset-2 hover:text-primary"
      href={href}
      rel="noopener noreferrer"
      target="_blank"
    >
      {children}
    </a>
  ),
  hr: () => <hr className="my-3 border-border" />,
  table: ({ children }) => (
    <div className="mt-2 overflow-x-auto first:mt-0">
      <table className="w-full border-collapse text-xs">{children}</table>
    </div>
  ),
  th: ({ children }) => <th className="border border-border px-2 py-1 text-left font-semibold text-foreground">{children}</th>,
  td: ({ children }) => <td className="border border-border px-2 py-1 text-muted-foreground">{children}</td>,
};

interface JournalMarkdownProps {
  content: string;
}

export function JournalMarkdown({ content }: JournalMarkdownProps) {
  return (
    <ReactMarkdown components={components} remarkPlugins={[remarkGfm]}>
      {content}
    </ReactMarkdown>
  );
}
