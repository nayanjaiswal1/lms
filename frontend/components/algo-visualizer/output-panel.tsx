interface OutputPanelProps {
  lines: string[];
}

export function OutputPanel({ lines }: OutputPanelProps) {
  return (
    <div className="flex h-full flex-col overflow-hidden rounded-lg border border-terminal-border bg-terminal">
      <div className="border-b border-terminal-border px-3 py-1.5 text-xs font-medium uppercase tracking-wide text-terminal-muted-foreground">
        Output
      </div>
      <div className="flex-1 overflow-auto px-3 py-2 font-mono text-sm text-terminal-foreground">
        {lines.length === 0 ? (
          <p className="text-terminal-muted-foreground">No output yet.</p>
        ) : (
          lines.map((line, i) => (
            <div className="whitespace-pre-wrap" key={i}>
              {line}
            </div>
          ))
        )}
      </div>
    </div>
  );
}
