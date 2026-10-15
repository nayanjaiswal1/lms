import { Star } from "lucide-react";
import { cn } from "@/lib/utils";

interface StarRatingProps {
  value: number;
  size?: "sm" | "md";
}

const STAR_SIZE = { sm: "h-3.5 w-3.5", md: "h-4 w-4" } as const;

// Decorative five-star row — callers always print the numeric rating next to
// it, so screen readers get the number rather than five unlabeled icons.
export function StarRating({ value, size = "md" }: StarRatingProps) {
  const rounded = Math.round(value);
  return (
    <span aria-hidden className="flex shrink-0 items-center gap-0.5 text-primary">
      {[1, 2, 3, 4, 5].map((n) => (
        <Star className={cn(STAR_SIZE[size], n > rounded && "text-border")} fill="currentColor" key={n} />
      ))}
    </span>
  );
}
