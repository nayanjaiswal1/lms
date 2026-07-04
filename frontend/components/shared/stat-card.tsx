import Link from "next/link";

interface StatCardProps {
  icon: React.ElementType;
  label: string;
  value: string;
  unit: string;
  highlighted?: boolean;
  muted?: boolean;
  href?: string;
}

export function StatCard({ icon: Icon, label, value, unit, highlighted = false, muted = false, href }: StatCardProps) {
  const inner = (
    <>
      <span
        className={`flex h-9 w-9 items-center justify-center rounded-md ${
          highlighted ? "bg-primary/10" : "bg-muted"
        }`}
      >
        <Icon
          aria-hidden
          className={`h-5 w-5 ${highlighted ? "text-primary" : "text-muted-foreground"}`}
        />
      </span>
      <div className="flex flex-col gap-0.5">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className={`text-2xl font-bold tabular-nums ${muted ? "text-muted-foreground" : ""}`}>
          {value}
        </p>
        <p className="text-xs text-muted-foreground">{unit}</p>
      </div>
    </>
  );

  if (href) {
    return (
      <Link href={href} className="card-interactive flex flex-col gap-3 p-5">
        {inner}
      </Link>
    );
  }

  return (
    <div className="card-base flex flex-col gap-3 p-5">
      {inner}
    </div>
  );
}
