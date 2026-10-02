import Link from "next/link";
import { ArrowLeft } from "lucide-react";

interface BackLinkProps {
  href: string;
  label: string;
}

export function BackLink({ href, label }: BackLinkProps) {
  return (
    <Link className="flex items-center gap-1.5 self-start text-sm text-muted-foreground hover:text-foreground" href={href}>
      <ArrowLeft aria-hidden className="h-4 w-4" />
      {label}
    </Link>
  );
}
