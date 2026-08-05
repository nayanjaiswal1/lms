import { AlertCircle } from "lucide-react";
import { IconMessage } from "@/components/shared/icon-message";

interface AuthFormErrorProps {
  message?: string;
}

export function AuthFormError({ message }: AuthFormErrorProps) {
  if (!message) return null;

  return (
    <IconMessage icon={AlertCircle} role="alert" tone="destructive">
      {message}
    </IconMessage>
  );
}
