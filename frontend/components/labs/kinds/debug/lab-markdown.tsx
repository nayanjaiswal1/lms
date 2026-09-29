import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"

interface LabMarkdownProps {
  children: string
}

/** Lab-authored markdown (ticket, root cause). Raw HTML stays escaped by react-markdown. */
export function LabMarkdown({ children }: LabMarkdownProps) {
  return (
    <div className="prose-content text-sm">
      <ReactMarkdown remarkPlugins={[remarkGfm]}>{children}</ReactMarkdown>
    </div>
  )
}
