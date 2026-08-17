import { ShieldCheck } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { PermissionMeta, RoleFull } from "@/app/(app)/users/[id]/types";

interface Props {
  roles: RoleFull[];
  overrides: PermissionMeta[];
  effectivePermissions: string[];
}

export function AccessTab({ roles, overrides, effectivePermissions }: Props) {
  return (
    <div className="space-y-6">
      <div className="card-base p-6">
        <h3 className="subsection-title text-foreground mb-2">RBAC roles</h3>
        {roles.length === 0 ? (
          <p className="text-sm text-muted-foreground">No RBAC roles assigned.</p>
        ) : (
          <div className="divide-y divide-border">
            {roles.map((role) => (
              <div className="flex items-start gap-3 py-3" key={role.id}>
                <ShieldCheck aria-hidden className="h-4 w-4 mt-0.5 shrink-0 text-muted-foreground" />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-medium text-foreground">{role.name}</p>
                    {role.is_system && <Badge variant="secondary">system</Badge>}
                  </div>
                  {role.description && (
                    <p className="text-sm text-muted-foreground mt-0.5">{role.description}</p>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {overrides.length > 0 && (
        <div className="card-base p-6">
          <h3 className="subsection-title text-foreground mb-2">Direct permission grants</h3>
          <p className="text-sm text-muted-foreground mb-3">
            Granted individually, bypassing roles entirely.
          </p>
          <div className="flex flex-wrap gap-2">
            {overrides.map((p) => (
              <Badge key={p.id} title={p.code} variant="outline">
                {p.name}
              </Badge>
            ))}
          </div>
        </div>
      )}

      <div className="card-base p-6">
        <h3 className="subsection-title text-foreground mb-2">
          Effective permissions <Badge className="ml-2" variant="secondary">{effectivePermissions.length}</Badge>
        </h3>
        {effectivePermissions.length === 0 ? (
          <p className="text-sm text-muted-foreground">No effective permissions.</p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {[...effectivePermissions].sort().map((code) => (
              <code className="kbd text-xs" key={code}>
                {code}
              </code>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
