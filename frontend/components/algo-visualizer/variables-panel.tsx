interface VariablesPanelProps {
  locals: Record<string, unknown>;
}

export function formatValue(v: unknown): string {
  if (v === null || v === undefined) return "None";
  if (v === true) return "True";
  if (v === false) return "False";
  if (typeof v === "string") return `'${v}'`;
  if (Array.isArray(v)) return `[${v.map(formatValue).join(", ")}]`;
  return String(v);
}

export function VariablesPanel({ locals }: VariablesPanelProps) {
  const entries = Object.entries(locals);
  return (
    <div className="card-base h-full overflow-auto">
      <p className="section-title mb-2">Variables</p>
      {entries.length === 0 ? (
        <p className="text-sm text-muted-foreground">No local variables yet.</p>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <tbody>
              {entries.map(([name, value]) => (
                <tr className="whitespace-nowrap border-b border-border last:border-0" key={name}>
                  <td className="py-1.5 pr-3 font-mono font-medium text-foreground">{name}</td>
                  <td className="py-1.5 font-mono text-muted-foreground">{formatValue(value)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
