"use client";

import { parseAsString, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Plus } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSwitchField } from "@/components/ui/form-switch-field";
import { useCurrency } from "@/lib/currency-context";
import { formatMoney, toMajorUnits, toMinorUnits } from "@/lib/money";
import { saveCreditPackAction, type CreditPack } from "@/lib/server/sessions";

const Schema = z.object({
  name: z.string().min(1, "Name is required.").max(120),
  description: z.string().max(500).optional(),
  sessions: z.coerce.number().int().positive("Must include at least 1 session."),
  price_major: z.coerce.number().nonnegative("Price can't be negative."),
  active: z.boolean(),
});
type FormInput = z.input<typeof Schema>;
type FormData = z.output<typeof Schema>;

interface PackFormDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  pack: CreditPack | null;
  orgCurrency: string;
}

// Reused for both create and edit — stays mounted while the manager's table
// is, so `values` (not `defaultValues`) re-syncs the form whenever the
// caller points it at a different pack (or none, for "new").
function PackFormDialog({ open, onOpenChange, pack, orgCurrency }: PackFormDialogProps) {
  const currency = pack?.currency ?? orgCurrency;
  const form = useForm<FormInput, unknown, FormData>({
    resolver: zodResolver(Schema),
    values: {
      name: pack?.name ?? "",
      description: pack?.description ?? "",
      sessions: pack?.sessions ?? 1,
      price_major: pack ? toMajorUnits(pack.price_cents, currency) : 0,
      active: pack?.active ?? true,
    },
  });

  const onSubmit = async (data: FormData) => {
    const res = await saveCreditPackAction({
      id: pack?.id,
      name: data.name.trim(),
      description: data.description?.trim() || undefined,
      sessions: data.sessions,
      price_cents: toMinorUnits(data.price_major, currency),
      active: data.active,
    });
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success(pack ? "Pack updated." : "Pack created.");
    onOpenChange(false);
  };

  const priceMajor = Number(form.watch("price_major")) || 0;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>{pack ? "Edit pack" : "New credit pack"}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Name" name="name" />
            <FormInputField control={form.control} label="Description (optional)" name="description" />
            <div className="form-row">
              <FormInputField control={form.control} label="Sessions included" name="sessions" type="number" />
              <FormInputField
                control={form.control}
                description={`Students will see ${formatMoney(toMinorUnits(priceMajor, currency), currency)}.`}
                label={`Price (${currency})`}
                name="price_major"
                step="0.01"
                type="number"
              />
            </div>
            <FormSwitchField
              control={form.control}
              description="Inactive packs are hidden from students but stay visible here."
              label="Active"
              name="active"
            />
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Saving…" : pack ? "Save changes" : "Create pack"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}

interface CreditPackManagerProps {
  packs: CreditPack[];
}

export function CreditPackManager({ packs }: CreditPackManagerProps) {
  const [editingId, setEditingId] = useQueryState("pack", parseAsString);
  const orgCurrency = useCurrency();
  const editingPack = editingId && editingId !== "new" ? (packs.find((p) => p.id === editingId) ?? null) : null;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex justify-end">
        <Button size="sm" onClick={() => void setEditingId("new")}>
          <Plus aria-hidden className="h-4 w-4" />
          New pack
        </Button>
      </div>
      {packs.length === 0 ? (
        <div className="empty-state py-10">
          <p className="text-sm text-muted-foreground">No credit packs yet.</p>
        </div>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="whitespace-nowrap border-b border-border text-left text-muted-foreground">
                <th className="pb-2 pr-6 font-medium">Name</th>
                <th className="pb-2 pr-6 font-medium">Sessions</th>
                <th className="pb-2 pr-6 font-medium">Price</th>
                <th className="pb-2 pr-6 font-medium">Status</th>
                <th className="pb-2 font-medium" />
              </tr>
            </thead>
            <tbody>
              {packs.map((pack) => (
                <tr className="whitespace-nowrap border-b border-border last:border-0" key={pack.id}>
                  <td className="min-w-0 py-3 pr-6">
                    <p className="font-medium">{pack.name}</p>
                    {pack.description && (
                      <p className="truncate text-xs text-muted-foreground">{pack.description}</p>
                    )}
                  </td>
                  <td className="py-3 pr-6 text-muted-foreground">{pack.sessions}</td>
                  <td className="py-3 pr-6 text-muted-foreground">{formatMoney(pack.price_cents, pack.currency)}</td>
                  <td className="py-3 pr-6">
                    {pack.active ? <Badge variant="default">Active</Badge> : <Badge variant="secondary">Inactive</Badge>}
                  </td>
                  <td className="py-3 text-right">
                    <Button size="sm" variant="outline" onClick={() => void setEditingId(pack.id)}>
                      Edit
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <PackFormDialog
        open={editingId !== null}
        orgCurrency={orgCurrency}
        pack={editingId === "new" ? null : editingPack}
        onOpenChange={(next) => void setEditingId(next ? (editingId ?? "new") : null)}
      />
    </div>
  );
}
