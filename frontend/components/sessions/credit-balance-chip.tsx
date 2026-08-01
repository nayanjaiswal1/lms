import Link from "next/link";
import { Coins } from "lucide-react";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

interface CreditBalanceChipProps {
  balance: number;
  className?: string;
}

/** Small badge showing the caller's session-credit balance, linking to the
 * credits store. Server component — the balance is passed down as a prop
 * from whatever server component already fetched it, never fetched here. */
export function CreditBalanceChip({ balance, className }: CreditBalanceChipProps) {
  return (
    <Link
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full border border-border bg-card px-3 py-1 text-sm font-medium text-foreground transition-colors duration-fast hover:bg-accent",
        className,
      )}
      href={ROUTES.SESSION_CREDITS}
    >
      <Coins aria-hidden className="h-4 w-4 text-primary" />
      {balance} session{balance === 1 ? "" : "s"} left
    </Link>
  );
}
