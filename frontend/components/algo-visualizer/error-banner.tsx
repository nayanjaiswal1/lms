import { AlertTriangle } from "lucide-react";

interface ErrorBannerProps {
  message: string;
}

export function ErrorBanner({ message }: ErrorBannerProps) {
  return (
    <div className="flex items-start gap-2 rounded-lg border border-destructive bg-destructive/10 px-4 py-3 text-sm text-destructive">
      <AlertTriangle aria-hidden className="mt-0.5 h-4 w-4 shrink-0" />
      <p className="font-mono">{message}</p>
    </div>
  );
}
