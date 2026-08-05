import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

const TONE_CLASSES: Record<string, string> = {
  neutral: "border-border bg-muted text-foreground",
  success: "border-border bg-muted text-foreground",
  destructive: "border-destructive/30 bg-destructive/10 text-destructive",
};

const ICON_TONE_CLASSES: Record<string, string> = {
  neutral: "text-muted-foreground",
  success: "text-primary",
  destructive: "text-destructive",
  ai: "text-ai",
};

const VARIANT_CLASSES: Record<string, string> = {
  card: "rounded-md border px-3 py-2.5",
  strip: "border-b px-4 py-2.5",
  plain: "",
};

const SIZE_CLASSES = {
  xs: { text: "text-xs", icon: "h-3.5 w-3.5" },
  sm: { text: "text-sm", icon: "h-4 w-4" },
  md: { text: "text-sm", icon: "h-5 w-5" },
} as const;

interface IconMessageProps {
  icon: LucideIcon;
  tone?: "neutral" | "success" | "destructive" | "ai";
  /** "card"/"strip" bring their own border+background; "plain" is bare (icon+text alignment only) for embedding inside an already-styled container (e.g. `ai-surface`, `card-base`) via `className`. */
  variant?: "card" | "strip" | "plain";
  size?: "xs" | "sm" | "md";
  role?: "alert" | "status";
  className?: string;
  /** One-off icon color/size override (e.g. a tone-less accent) — merged over the tone's default. */
  iconClassName?: string;
  /** Optional trailing action (e.g. a dismiss button) — rendered shrink-0 at the end of the row. */
  action?: React.ReactNode;
  children: React.ReactNode;
}

// Icon pinned to the first line via items-start + mt-0.5 — items-center
// re-centers the icon against the whole block once the message wraps.
// Root is a div (not p) so multi-line/block children (e.g. a title +
// description pair) don't produce invalid nested-block HTML.
export function IconMessage({
  icon: Icon,
  tone = "neutral",
  variant = "card",
  size = "sm",
  role,
  className,
  iconClassName,
  action,
  children,
}: IconMessageProps) {
  return (
    <div
      className={cn(
        "flex items-start gap-2",
        VARIANT_CLASSES[variant],
        variant !== "plain" && TONE_CLASSES[tone],
        SIZE_CLASSES[size].text,
        className,
      )}
      role={role}
    >
      <Icon
        aria-hidden
        className={cn(SIZE_CLASSES[size].icon, "mt-0.5 shrink-0", ICON_TONE_CLASSES[tone], iconClassName)}
      />
      <div className="min-w-0 flex-1">{children}</div>
      {action && <div className="shrink-0">{action}</div>}
    </div>
  );
}
