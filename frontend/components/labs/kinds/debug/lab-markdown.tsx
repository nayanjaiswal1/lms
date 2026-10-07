import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"

interface LabMarkdownProps {
  children: string
}

// Compact reading scale for a narrow panel: 14px body on 24px lines, a 16px
// title, 12px uppercase section labels, 0.85em mono code chips. Global `p`/`code`/`pre`
// base styles are sized for full-width pages, so they are overridden here.
const LAB_PROSE = [
  "prose-content text-sm leading-6 [&>*+*]:mt-3",
  "[&_p]:leading-6",
  "[&>h1]:text-base [&>h1]:font-semibold [&>h1]:leading-snug",
  "[&>h2]:mb-0 [&>h2]:mt-6 [&>h2]:border-0 [&>h2]:pb-0 [&>h2]:text-xs [&>h2]:font-semibold [&>h2]:uppercase [&>h2]:leading-5 [&>h2]:tracking-wider [&>h2]:text-muted-foreground",
  "[&>h2+*]:mt-1.5",
  "[&>h3]:mb-0 [&>h3]:mt-4 [&>h3]:text-sm [&>h3]:font-semibold [&>h3]:leading-6",
  "[&_li]:leading-6 [&_ul]:space-y-1 [&_ol]:space-y-1",
  "[&_code]:rounded-md [&_code]:border [&_code]:border-border [&_code]:bg-muted [&_code]:px-1.5 [&_code]:py-px [&_code]:text-[0.85em] [&_code]:font-medium [&_code]:break-words",
  "[&_pre]:rounded-lg [&_pre]:p-3 [&_pre]:text-xs [&_pre]:leading-5 [&_pre_code]:border-0 [&_pre_code]:bg-transparent [&_pre_code]:p-0 [&_pre_code]:text-xs",
].join(" ")

/** Lab-authored markdown (ticket, root cause). Raw HTML stays escaped by react-markdown. */
export function LabMarkdown({ children }: LabMarkdownProps) {
  return (
    <div className={LAB_PROSE}>
      <ReactMarkdown remarkPlugins={[remarkGfm]}>{children}</ReactMarkdown>
    </div>
  )
}
