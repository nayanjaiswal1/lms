"use client";

import { usePathname, useRouter } from "next/navigation";
import ROUTES from "@/lib/routes";

const LEETCODE_HREF = /^https:\/\/leetcode\.com\/problems\/([a-z0-9-]+)\/?$/;

interface LessonHtmlProps {
  html: string;
  // Index of this segment within the lesson's segment list — lets the
  // highlight flow anchor a selection to "segment N, occurrence M" instead
  // of matching by text alone. Omit for html rendered outside a highlight
  // context (e.g. the design guidance panel).
  segmentIndex?: number;
}

// Lesson html segment with one job on top of dangerouslySetInnerHTML:
// clicks on LeetCode problem links open the in-app solve page instead of
// navigating away. Course slug and module id come from the learn-page path
// (/courses/[slug]/learn/[moduleId]) so the solve page can link back.
export function LessonHtml({ html, segmentIndex }: LessonHtmlProps) {
  const router = useRouter();
  const pathname = usePathname();

  function onClick(event: React.MouseEvent<HTMLDivElement>) {
    const anchor = (event.target as HTMLElement).closest("a");
    if (!anchor) return;
    const match = LEETCODE_HREF.exec(anchor.href);
    if (!match) return;
    const path = /^\/courses\/([^/]+)\/learn\/([^/]+)/.exec(pathname);
    if (!path) return;
    event.preventDefault();
    const query = new URLSearchParams({
      title: anchor.textContent?.trim() ?? match[1],
      module: path[2],
    });
    router.push(`${ROUTES.courseSolve(path[1], match[1])}?${query}`);
  }

  return (
    // eslint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/no-static-element-interactions -- delegated handler for the native <a> links inside the html; Enter on a focused link fires click, so keyboard access is native
    <div
      className="prose-content"
      dangerouslySetInnerHTML={{ __html: html }}
      data-segment-index={segmentIndex}
      onClick={onClick}
    />
  );
}
