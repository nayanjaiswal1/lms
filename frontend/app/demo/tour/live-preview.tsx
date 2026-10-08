"use client";

import { useEffect } from "react";

const RESULT_MESSAGE = "mf-demo-lab-result";

interface LivePreviewProps {
  /** Body markup of the previewed page. */
  html: string;
  css: string;
  /** Learner code, run before the harness. */
  script: string;
  /** JS expression evaluating to one boolean per lab task. */
  harness: string;
  /** Bumped on every Run to force a fresh iframe. */
  runKey: number;
  /** The page's CSP nonce — srcdoc iframes inherit the parent policy. */
  nonce: string;
  onResults: (results: boolean[]) => void;
}

// Escape "</" so learner code can never close the injected tag early.
function safe(source: string): string {
  return source.replace(/<\//g, "<\\/");
}

function buildDoc({ html, css, script, harness, nonce }: LivePreviewProps): string {
  return `<!doctype html><meta charset="utf-8"><style>body{font-family:system-ui;padding:16px}${safe(css)}</style>
<body>${html}
<script nonce="${nonce}">
try {
${safe(script)}
parent.postMessage({ type: "${RESULT_MESSAGE}", results: ${harness} }, "*");
} catch (e) {
  document.body.insertAdjacentText("beforeend", "Error: " + e.message);
  parent.postMessage({ type: "${RESULT_MESSAGE}", results: [] }, "*");
}
</script></body>`;
}

// The learner's code runs in a sandboxed iframe (scripts only, no same-origin
// access) and reports task results back by postMessage.
export function LivePreview(props: LivePreviewProps) {
  const { onResults, runKey } = props;

  // Subscribing to window messages is an external-system sync, not data fetching.
  useEffect(() => {
    function onMessage(e: MessageEvent) {
      if (e.data?.type !== RESULT_MESSAGE || !Array.isArray(e.data.results)) return;
      onResults(e.data.results as boolean[]);
    }
    window.addEventListener("message", onMessage);
    return () => window.removeEventListener("message", onMessage);
  }, [onResults]);

  return (
    <iframe
      className="min-h-64 w-full flex-1 rounded-md border border-border bg-background"
      key={runKey}
      sandbox="allow-scripts"
      srcDoc={buildDoc(props)}
      title="Live preview of your app"
    />
  );
}
