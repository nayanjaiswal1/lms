import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

/**
 * Merge class names with Tailwind conflict resolution.
 * Always use this for className composition — never string concatenation.
 *   cn("px-2", condition && "px-4")  → "px-4"
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/**
 * Validate a post-login `?next=` redirect target: must be an internal path
 * (single leading slash, no protocol-relative `//host` open-redirect trick).
 */
export function safeNextPath(next: string | undefined | null): string | null {
  if (!next || !next.startsWith("/") || next.startsWith("//")) return null;
  return next;
}

/**
 * Human-readable file size, e.g. 542000 -> "529.3 KB".
 */
export function formatBytes(bytes: number): string {
  if (bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const exponent = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / 1024 ** exponent;
  return `${exponent === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[exponent]}`;
}
