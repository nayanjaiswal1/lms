import { Badge } from "@/components/ui/badge";

interface PermissionInfo {
  code: string;
  name: string;
  description?: string;
}

interface Props {
  codes: string[];
  catalog: PermissionInfo[];
}

// Effective-permission endpoints return bare codes (e.g. "admin.manage_members");
// admins should see the human name, with the description on hover. Unknown
// codes (inactive/removed permissions) fall back to the code itself.
export function PermissionNameList({ codes, catalog }: Props) {
  const byCode = new Map(catalog.map((p) => [p.code, p]));
  const items = codes
    .map((code) => byCode.get(code) ?? { code, name: code, description: undefined })
    .sort((a, b) => a.name.localeCompare(b.name));

  return (
    <div className="flex flex-wrap gap-2">
      {items.map((p) => (
        <Badge key={p.code} title={p.description || undefined} variant="outline">
          {p.name}
        </Badge>
      ))}
    </div>
  );
}
