import { PERMISSIONS } from "@/lib/auth/permission-codes";

// A persona is a dashboard "lens", derived only from permission codes (never
// role names). Order below is resolution priority, highest first.
export const PERSONAS = {
  admin: { label: "Admin", marker: PERMISSIONS.ADMIN.MANAGE_ORG },
  teach: { label: "Teach", marker: PERMISSIONS.COURSES.CREATE },
  mentor: { label: "Mentor", marker: PERMISSIONS.MENTORING.MANAGE_BATCHES },
  support: { label: "Support", marker: PERMISSIONS.SUPPORT.MANAGE },
  learn: { label: "Learn", marker: PERMISSIONS.PRACTICE.USE },
} as const;

export type Persona = keyof typeof PERSONAS;
/** Read-only fallback for users holding no persona marker (courses only). */
export type ResolvedPersona = Persona | "viewer";

const ORDER = Object.keys(PERSONAS) as Persona[];

export function isPersona(value: unknown): value is Persona {
  return typeof value === "string" && value in PERSONAS;
}

export function availablePersonas(perms: readonly string[]): Persona[] {
  return ORDER.filter((p) => perms.includes(PERSONAS[p].marker));
}

export function resolvePersona(perms: readonly string[], preferred?: string | null): ResolvedPersona {
  const available = availablePersonas(perms);
  if (isPersona(preferred) && available.includes(preferred)) return preferred;
  return available[0] ?? "viewer";
}
