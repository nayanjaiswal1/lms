import Link from "next/link";
import type { Metadata } from "next";
import { AlertTriangle, ArrowUpCircle, Blocks, Plus, Wrench } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { BuildStatusBadge } from "@/components/labs/builder/build-status-badge";
import { getRecipes, requireLabAuthor } from "@/lib/labs/builder/server";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Debug labs" };

// docs/debug-labs.md B4: the author's recipes with their latest build status.
export default async function DebugLabBuilderPage() {
  await requireLabAuthor();
  const recipes = await getRecipes();

  return (
    <main className="page-container flex flex-col gap-4">
      <div className="page-header py-2">
        <h1 className="page-title">Debug labs</h1>
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
        <ResponsiveTable>
          <table className="w-full text-sm">
            <thead>
              <tr className="whitespace-nowrap border-b border-border text-left text-muted-foreground">
                <th className="pb-2 pr-4 font-medium">Lab</th>
                <th className="pb-2 pr-4 font-medium">Build</th>
                <th className="pb-2 pr-4 font-medium">Blocks</th>
                <th className="pb-2 pr-4 font-medium">Revision</th>
                <th className="pb-2 pr-4 font-medium">Published</th>
                <th className="pb-2 font-medium">Updated</th>
              </tr>
            </thead>
            <tbody>
              {recipes.map((r) => (
                <tr className="whitespace-nowrap border-b border-border last:border-0" key={r.id}>
                  <td className="min-w-0 max-w-sm py-2.5 pr-4">
                    <Link className="block truncate font-medium hover:text-primary hover:underline" href={ROUTES.labBuilderRecipe(r.id)}>
                      {r.title}
                    </Link>
                    {r.yanked_blocks > 0 && (
                      <p className="flex items-center gap-1 text-xs text-destructive">
                        <AlertTriangle aria-hidden className="h-3 w-3" />
                        {r.yanked_blocks} yanked block{r.yanked_blocks === 1 ? "" : "s"}
                      </p>
                    )}
                    {r.updates_available > 0 && (
                      <p className="flex items-center gap-1 text-xs text-primary">
                        <ArrowUpCircle aria-hidden className="h-3 w-3" />
                        {r.updates_available} update{r.updates_available === 1 ? "" : "s"} available
                      </p>
                    )}
                  </td>
                  <td className="py-2.5 pr-4"><BuildStatusBadge status={r.latest_build?.status ?? null} /></td>
                  <td className="py-2.5 pr-4 tabular-nums text-muted-foreground">{r.spec.blocks.length}</td>
                  <td className="py-2.5 pr-4 tabular-nums text-muted-foreground">r{r.revision}</td>
                  <td className="py-2.5 pr-4 text-muted-foreground">{r.lab_id ? "Yes" : "No"}</td>
                  <td className="py-2.5 text-muted-foreground">{new Date(r.updated_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </ResponsiveTable>
      )}
    </main>
  );
}
