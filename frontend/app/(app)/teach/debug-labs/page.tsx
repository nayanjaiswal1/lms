import Link from "next/link";
import type { Metadata } from "next";
import { Blocks, Plus, Wrench } from "lucide-react";
import { Button } from "@/components/ui/button";
import { BuildStatusBadge } from "@/components/labs/builder/build-status-badge";
import { getRecipes, requireLabAuthor } from "@/lib/labs/builder/server";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Debug lab builder" };

// docs/debug-labs.md B4: the author's recipes with their latest build status.
export default async function DebugLabBuilderPage() {
  await requireLabAuthor();
  const recipes = await getRecipes();

  return (
    <main className="page-container flex flex-col gap-6">
      <div className="page-header">
        <div>
          <h1 className="page-title">Debug lab builder</h1>
          <p className="text-sm text-muted-foreground">
            Compose production-debugging labs from tested blocks, verify them automatically, then publish into a course.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button asChild variant="outline">
            <Link href={ROUTES.LAB_BUILDER_BLOCKS}>
              <Blocks aria-hidden className="h-4 w-4" />
              Block library
            </Link>
          </Button>
          <Button asChild>
            <Link href={ROUTES.labBuilderNew()}>
              <Plus aria-hidden className="h-4 w-4" />
              New debug lab
            </Link>
          </Button>
        </div>
      </div>

      {recipes.length === 0 ? (
        <div className="empty-state">
          <Wrench aria-hidden className="empty-state-icon" />
          <p>No debug labs yet. Start one from a base app and a fault.</p>
        </div>
      ) : (
        <ul className="card-grid">
          {recipes.map((r) => (
            <li key={r.id}>
              <Link className="card-interactive flex h-full flex-col gap-3" href={ROUTES.labBuilderRecipe(r.id)}>
                <div className="flex items-start justify-between gap-3">
                  <h2 className="min-w-0 text-base font-semibold">{r.title}</h2>
                  <BuildStatusBadge status={r.latest_build?.status ?? null} />
                </div>
                <p className="text-xs text-muted-foreground">
                  {r.spec.blocks.length} block{r.spec.blocks.length === 1 ? "" : "s"} · revision {r.revision}
                  {r.lab_id ? " · published" : ""}
                </p>
                <p className="mt-auto text-xs text-muted-foreground">
                  Updated {new Date(r.updated_at).toLocaleDateString()}
                </p>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
