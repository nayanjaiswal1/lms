// Must stay in sync with pistonLabLanguages (backend/internal/labs/piston.go).
// Plain module (no "use client") so ModuleNotes, a Server Component, can call
// isRunnableLanguage() directly — every export of a "use client" file becomes
// a client reference, which throws if invoked from server code.
export const RUNNABLE_LANGUAGES: Record<string, string> = {
  javascript: "JavaScript",
  python: "Python",
  python3: "Python",
  typescript: "TypeScript",
  go: "Go",
};

export function isRunnableLanguage(language: string): boolean {
  return language.trim().toLowerCase() in RUNNABLE_LANGUAGES;
}
