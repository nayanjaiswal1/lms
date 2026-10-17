// Pure any-of permission checks shared by every nav surface (lib/nav.ts, org
// settings nav) so the filter semantics live in one place.
export interface PermissionGated {
  requiredPermission?: string | string[];
  hideForPermission?: string | string[];
}

export const holdsAny = (perms: ReadonlySet<string>, codes: string | string[]): boolean =>
  (Array.isArray(codes) ? codes : [codes]).some((p) => perms.has(p));

export const isPermitted = (item: PermissionGated, perms: ReadonlySet<string>): boolean =>
  (!item.requiredPermission || holdsAny(perms, item.requiredPermission)) &&
  (!item.hideForPermission || !holdsAny(perms, item.hideForPermission));
