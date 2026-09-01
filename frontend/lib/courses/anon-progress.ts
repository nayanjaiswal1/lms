// Client-side-only progress tracking for anonymous course browsing
// (docs/anonymous.md). Nothing here ever reaches the server until the
// visitor logs in — see components/courses/anon-progress-migrator.tsx, which
// reads exactly this shape and posts it to
// POST /api/courses/{courseID}/anon-progress/migrate.
//
// Storage key is per-course (`mf_anon_progress:{courseId}`) rather than one
// blob for every course a visitor browsed — keeps each read/write small and
// lets listAnonProgress() enumerate courses without parsing unrelated data.

const KEY_PREFIX = "mf_anon_progress:";

export interface AnonCourseProgress {
  completedModuleIds: string[];
  notes: Record<string, string>;
  reflections: Record<string, string>;
}

const EMPTY: AnonCourseProgress = { completedModuleIds: [], notes: {}, reflections: {} };

function key(courseId: string): string {
  return `${KEY_PREFIX}${courseId}`;
}

function readRaw(courseId: string): AnonCourseProgress {
  if (typeof window === "undefined") return EMPTY;
  try {
    const raw = window.localStorage.getItem(key(courseId));
    if (!raw) return EMPTY;
    const parsed = JSON.parse(raw) as Partial<AnonCourseProgress>;
    return {
      completedModuleIds: Array.isArray(parsed.completedModuleIds) ? parsed.completedModuleIds : [],
      notes: parsed.notes && typeof parsed.notes === "object" ? parsed.notes : {},
      reflections: parsed.reflections && typeof parsed.reflections === "object" ? parsed.reflections : {},
    };
  } catch {
    return EMPTY;
  }
}

function writeRaw(courseId: string, progress: AnonCourseProgress): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(key(courseId), JSON.stringify(progress));
  } catch {
    // Storage full or unavailable (private browsing) — the lesson still
    // works, it just won't remember this change across reloads.
  }
}

export function getAnonProgress(courseId: string): AnonCourseProgress {
  return readRaw(courseId);
}

export function setAnonModuleCompleted(courseId: string, moduleId: string, completed: boolean): AnonCourseProgress {
  const current = readRaw(courseId);
  const set = new Set(current.completedModuleIds);
  if (completed) set.add(moduleId);
  else set.delete(moduleId);
  const next = { ...current, completedModuleIds: [...set] };
  writeRaw(courseId, next);
  return next;
}

export function setAnonNote(courseId: string, moduleId: string, content: string): void {
  const current = readRaw(courseId);
  writeRaw(courseId, { ...current, notes: { ...current.notes, [moduleId]: content } });
}

export function setAnonReflection(courseId: string, moduleId: string, response: string): void {
  const current = readRaw(courseId);
  writeRaw(courseId, { ...current, reflections: { ...current.reflections, [moduleId]: response } });
}

export function clearAnonProgress(courseId: string): void {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(key(courseId));
}

// Enumerates every course a visitor built up anonymous progress on, for the
// post-login migrator to walk through. Skips a course with nothing worth
// migrating (no completions, notes, or reflections) rather than making the
// migrator re-derive that.
export function listAnonProgress(): { courseId: string; progress: AnonCourseProgress }[] {
  if (typeof window === "undefined") return [];
  const out: { courseId: string; progress: AnonCourseProgress }[] = [];
  for (let i = 0; i < window.localStorage.length; i++) {
    const k = window.localStorage.key(i);
    if (!k || !k.startsWith(KEY_PREFIX)) continue;
    const courseId = k.slice(KEY_PREFIX.length);
    const progress = readRaw(courseId);
    if (progress.completedModuleIds.length || Object.keys(progress.notes).length || Object.keys(progress.reflections).length) {
      out.push({ courseId, progress });
    }
  }
  return out;
}
