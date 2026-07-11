import { notFound, redirect } from "next/navigation";
import Link from "next/link";
import { MessageSquare, BookOpen, Users, BarChart3 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { BatchAvatar } from "@/components/batches/batch-avatar";
import { getBatch, getOrgId } from "@/lib/server/batches";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
  children: React.ReactNode;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const batch = await getBatch(id).catch(() => null);
  return { title: batch ? `${batch.name} — MindForge` : "Batch — MindForge" };
}

export default async function BatchLayout({ params, children }: Props) {
  const { id } = await params;
  const orgId = await getOrgId();

  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const batch = await getBatch(id).catch(() => null);
  if (!batch) notFound();

  const TABS = [
    { href: ROUTES.batch(id), label: "People", Icon: Users },
    { href: `${ROUTES.batch(id)}/courses`, label: "Courses", Icon: BookOpen },
    { href: `${ROUTES.batch(id)}/progress`, label: "Progress", Icon: BarChart3 },
    { href: `${ROUTES.batch(id)}/chat`, label: "Chat", Icon: MessageSquare },
  ] as const;

  return (
    <main className="page-container py-8">
      <div className="page-header">
        <div className="flex items-center gap-3">
          <BatchAvatar batchId={batch.id} imageUrl={batch.image_url} name={batch.name} size="md" />
          <div className="flex flex-col gap-2">
            <div className="flex items-center gap-2">
              <h1 className="page-title">{batch.name}</h1>
              <Badge variant={batch.status === "active" ? "default" : "secondary"}>
                {batch.status}
              </Badge>
            </div>
            {batch.description && (
              <p className="text-sm text-muted-foreground">{batch.description}</p>
            )}
            {(batch.starts_at || batch.ends_at) && (
              <p className="text-xs text-muted-foreground">
                {batch.starts_at && new Date(batch.starts_at).toLocaleDateString()}
                {batch.ends_at && ` – ${new Date(batch.ends_at).toLocaleDateString()}`}
              </p>
            )}
          </div>
        </div>
      </div>

      <nav aria-label="Batch sections" className="mb-6 flex gap-1 border-b border-border overflow-x-auto">
        {TABS.map(({ href, label, Icon }) => (
          <Link
            className="flex items-center gap-1.5 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors duration-fast border-transparent text-muted-foreground hover:text-foreground whitespace-nowrap"
            href={href}
            key={href}
          >
            <Icon aria-hidden className="h-4 w-4" />
            {label}
          </Link>
        ))}
      </nav>

      <div>{children}</div>
    </main>
  );
}
