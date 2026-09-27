import { Skeleton } from "@/components/ui/skeleton";

export default function OnboardingLoading() {
  return (
    <div className="flex flex-col gap-2">
      <Skeleton className="h-5 w-40" />
      {Array.from({ length: 4 }).map((_, i) => (
        <Skeleton className="h-14 w-full" key={i} />
      ))}
    </div>
  );
}
