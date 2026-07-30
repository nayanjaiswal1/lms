import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { ListChecks } from "lucide-react";

import ROUTES from "@/lib/routes";
import { getSheetPreview } from "@/lib/server/sheets";
import { joinSheetAction } from "@/lib/sheets/actions";
import { Button } from "@/components/ui/button";
import { Breadcrumb } from "@/components/shared/breadcrumb";

export const metadata: Metadata = { title: "Join a sheet" };

interface JoinSheetPageProps {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ error?: string }>;
}

export default async function JoinSheetPage({ params, searchParams }: JoinSheetPageProps) {
  const { slug } = await params;
  const { error } = await searchParams;
  const preview = await getSheetPreview(slug);

  if (preview.is_subscribed) redirect(ROUTES.sheet(slug));

  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ label: "Sheets", href: ROUTES.SHEETS }, { label: "Join" }]} />
      <div className="card-base flex flex-col items-center gap-3 p-8 text-center">
        <ListChecks aria-hidden className="h-10 w-10 text-primary" />
        <h1 className="section-title">{preview.name}</h1>
        {preview.description && <p className="text-sm text-muted-foreground">{preview.description}</p>}
        <p className="text-xs text-muted-foreground">
          {preview.item_count} question{preview.item_count === 1 ? "" : "s"}
        </p>
        {error && <p className="text-sm text-destructive">Couldn&apos;t join this sheet. Please try again.</p>}
        <form action={joinSheetAction.bind(null, preview.id, slug)}>
          <Button type="submit">Subscribe &amp; open</Button>
        </form>
        <Link className="text-sm text-muted-foreground hover:text-foreground" href={ROUTES.SHEETS}>
          Not now — back to my sheets
        </Link>
      </div>
    </main>
  );
}
