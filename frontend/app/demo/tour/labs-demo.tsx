import Link from "next/link";

import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";
import { DebugLabDemo } from "@/app/demo/tour/debug-lab-demo";
import { IdeLabDemo } from "@/app/demo/tour/ide-lab-demo";
import { DockerLabDemo } from "@/app/demo/tour/docker-lab-demo";
import { DEMO_LAB_KINDS, type DemoLabKind } from "@/app/demo/tour/mock-data";

interface LabsDemoProps {
  kind: DemoLabKind;
  nonce: string;
}

export function LabsDemo({ kind, nonce }: LabsDemoProps) {
  return (
    <div className="flex flex-col gap-6">
      <nav aria-label="Lab type" className="flex gap-1 self-start rounded-full bg-muted p-1">
        {DEMO_LAB_KINDS.map(({ id, label }) => (
          <Link
            aria-current={id === kind ? "true" : undefined}
            className={cn(
              "rounded-full px-4 py-1.5 text-sm font-medium no-underline hover:no-underline",
              id === kind ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground",
            )}
            href={`${ROUTES.DEMO_TOUR}?tab=labs&lab=${id}`}
            key={id}
          >
            {label}
          </Link>
        ))}
      </nav>
      {kind === "docker" ? <DockerLabDemo /> : kind === "ide" ? <IdeLabDemo nonce={nonce} /> : <DebugLabDemo nonce={nonce} />}
    </div>
  );
}
