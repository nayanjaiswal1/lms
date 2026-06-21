import { AlertCircle } from "lucide-react";

interface AuthFormErrorProps {
  message?: string;
}

export function AuthFormError({ message }: AuthFormErrorProps) {
  if (!message) return null;

  return (
    <p
      className="flex items-start gap-2 rounded-md border border-destructive/25 bg-destructive/10 px-3 py-2.5 text-sm text-destructive"
      role="alert"
    >
      <AlertCircle aria-hidden className="mt-0.5 h-4 w-4 shrink-0" />
      <span>{message}</span>
    </p>
  );
}
