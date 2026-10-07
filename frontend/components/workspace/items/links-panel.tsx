"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { ArrowLeft, ArrowRight, Link2, X } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Form, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { ItemSearchPicker } from "@/components/workspace/items/item-search-picker";
import { createLinkAction, deleteLinkAction } from "@/lib/workspace/items-actions";
import type { ItemDetail, LinkKind, WorkItem } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

const KIND_OPTIONS: { label: string; value: LinkKind }[] = [
  { label: "Blocks", value: "blocks" },
  { label: "Relates to", value: "relates" },
  { label: "Duplicates", value: "duplicates" },
];

const Schema = z.object({ kind: z.enum(["blocks", "relates", "duplicates"]) });
type FormData = z.infer<typeof Schema>;

interface LinksPanelProps {
  workspaceId: string;
  item: ItemDetail;
}

export function LinksPanel({ workspaceId, item }: LinksPanelProps) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [target, setTarget] = useState<WorkItem | null>(null);
  const [pending, setPending] = useState(false);
  const form = useForm<FormData>({ resolver: zodResolver(Schema), defaultValues: { kind: "relates" } });

  async function onAdd(data: FormData) {
    if (!target) {
      toast.error("Pick the item to link.");
      return;
    }
    setPending(true);
    const result = await createLinkAction(workspaceId, item.id, { to_item_id: target.id, kind: data.kind });
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(data.kind === "duplicates" ? `Linked as a duplicate of ${target.key} — this item was closed.` : "Link added.");
    setOpen(false);
    setTarget(null);
    form.reset({ kind: "relates" });
    router.refresh();
  }

  async function remove(toItemId: string, kind: LinkKind) {
    setPending(true);
    const result = await deleteLinkAction(workspaceId, item.id, toItemId, kind);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-medium text-muted-foreground">Links</h2>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button aria-label="Add link" size="icon" variant="ghost">
              <Link2 aria-hidden className="h-4 w-4" />
            </Button>
          </DialogTrigger>
          <DialogContent className="modal-responsive">
            <DialogHeader><DialogTitle>Add link</DialogTitle></DialogHeader>
            <Form {...form}>
              <form className="form-stack" onSubmit={form.handleSubmit(onAdd)}>
                <FormSelectField control={form.control} label="Kind" name="kind" options={KIND_OPTIONS} />
                <FormField
                  control={form.control}
                  name="kind"
                  render={() => (
                    <FormItem>
                      <FormLabel>Item</FormLabel>
                      <ItemSearchPicker excludeItemId={item.id} placeholder="Search by key or title…" value={target} workspaceId={workspaceId} onChange={setTarget} />
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <DialogFooter>
                  <Button disabled={pending} type="submit">{pending ? "Linking…" : "Add link"}</Button>
                </DialogFooter>
              </form>
            </Form>
          </DialogContent>
        </Dialog>
      </div>

      {item.links.length === 0 && <p className="text-sm text-muted-foreground">No links yet.</p>}

      <ul className="flex flex-col gap-1.5">
        {item.links.map((l) => (
          <li className="flex items-center justify-between gap-2 text-sm" key={`${l.kind}-${l.direction}-${l.other.id}`}>
            <div className="flex min-w-0 items-center gap-1.5">
              {l.direction === "outgoing" ? <ArrowRight aria-hidden className="h-3.5 w-3.5 shrink-0 text-muted-foreground" /> : <ArrowLeft aria-hidden className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />}
              <Badge variant="outline">{l.kind}</Badge>
              <Link className="truncate hover:text-primary hover:underline" href={ROUTES.workspaceItem(workspaceId, l.other.key)}>
                {l.other.key} — {l.other.title}
              </Link>
            </div>
            <Button aria-label={`Remove link to ${l.other.key}`} disabled={pending} type="button" variant="unstyled" onClick={() => remove(l.other.id, l.kind)}>
              <X className="h-3.5 w-3.5 text-muted-foreground hover:text-destructive" />
            </Button>
          </li>
        ))}
      </ul>
    </div>
  );
}
