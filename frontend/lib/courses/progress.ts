import type { ModuleProgress } from "@/lib/server/courses";

export function moduleStatus(moduleId: string, progress: ModuleProgress[]): ModuleProgress["status"] {
  return progress.find((p) => p.module_id === moduleId)?.status ?? "not_started";
}

export function computeCompletion(moduleIds: string[], progress: ModuleProgress[]): { completed: number; total: number } {
  const completed = moduleIds.filter((id) => moduleStatus(id, progress) === "completed").length;
  return { completed, total: moduleIds.length };
}
