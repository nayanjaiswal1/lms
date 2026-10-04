import Link from "next/link";
import { Library } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { getBundles, getManagedBundles } from "@/lib/server/bundles";
import ROUTES from "@/lib/routes";

interface BundleGridProps {
  canManage: boolean;
}

// Bundles strip on /courses. Instructors see drafts too so they can find
// what they're still building; renders nothing when there are no bundles.
export async function BundleGrid({ canManage }: BundleGridProps) {
  const bundles = await (canManage ? getManagedBundles() : getBundles()).catch(() => []);
  if (bundles.length === 0) return null;

  return (
    <section aria-labelledby="bundles-heading" className="mb-8">
      <h2 className="section-title mb-4" id="bundles-heading">Bundles</h2>
      <div className="card-grid">
        {bundles.map((bundle) => (
          <article className="card-interactive relative flex flex-col gap-2 p-6" key={bundle.id}>
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <Library aria-hidden className="h-4 w-4 text-primary" />
              <span>
                {bundle.course_count} course{bundle.course_count === 1 ? "" : "s"}
              </span>
              {bundle.status === "draft" && <Badge variant="outline">Draft</Badge>}
            </div>
            <Link
              className="line-clamp-2 font-semibold leading-snug after:absolute after:inset-0 after:content-['']"
              href={ROUTES.bundle(bundle.slug)}
            >
              {bundle.title}
            </Link>
            {bundle.description && (
              <p className="line-clamp-2 text-sm text-muted-foreground">{bundle.description}</p>
            )}
          </article>
        ))}
      </div>
    </section>
  );
}
