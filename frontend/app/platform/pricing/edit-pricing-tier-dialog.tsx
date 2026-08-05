"use client";

import { parseAsString, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSwitchField } from "@/components/ui/form-switch-field";
import { Textarea } from "@/components/ui/textarea";
import type { PricingTier } from "@/lib/server/pricing";
import { updatePricingTierAction } from "./actions";

const Schema = z.object({
  name: z.string().trim().min(1, "Required"),
  price: z.string().trim().min(1, "Required"),
  billing_note: z.string().trim().min(1, "Required"),
  tagline: z.string().trim().min(1, "Required"),
  features: z.string().trim().min(1, "Add at least one feature, one per line"),
  cta_label: z.string().trim().min(1, "Required"),
  cta_disabled: z.boolean(),
  cta_href: z.string().trim().optional(),
  highlighted: z.boolean(),
});
type FormData = z.infer<typeof Schema>;

function toFormValues(tier: PricingTier): FormData {
  return {
    name: tier.name,
    price: tier.price,
    billing_note: tier.billing_note,
    tagline: tier.tagline,
    features: tier.features.join("\n"),
    cta_label: tier.cta_label,
    cta_disabled: tier.cta_disabled,
    cta_href: tier.cta_href ?? "",
    highlighted: tier.highlighted,
  };
}

interface EditPricingTierDialogProps {
  tier: PricingTier;
}

export function EditPricingTierDialog({ tier }: EditPricingTierDialogProps) {
  const [openId, setOpenId] = useQueryState("edit-tier", parseAsString);
  const isOpen = openId === tier.id;

  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: toFormValues(tier),
  });
  const ctaEnabled = !form.watch("cta_disabled");

  const onSubmit = async (data: FormData) => {
    const res = await updatePricingTierAction(tier.id, {
      name: data.name,
      price: data.price,
      billing_note: data.billing_note,
      tagline: data.tagline,
      features: data.features.split("\n").map((line) => line.trim()).filter(Boolean),
      cta_label: data.cta_label,
      cta_disabled: data.cta_disabled,
      cta_href: data.cta_disabled ? undefined : data.cta_href,
      highlighted: data.highlighted,
    });
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success(`${tier.name} updated — live on the landing page now.`);
    void setOpenId(null);
  };

  return (
    <Dialog
      open={isOpen}
      onOpenChange={(next) => {
        if (!next) {
          void setOpenId(null);
          return;
        }
        form.reset(toFormValues(tier));
        void setOpenId(tier.id);
      }}
    >
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          Edit
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Edit {tier.name}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Name" name="name" />
            <div className="stack-sm">
              <FormInputField control={form.control} label="Price" name="price" placeholder="₹299 or Contact us" />
              <FormInputField control={form.control} label="Billing note" name="billing_note" placeholder="/month, forever, custom…" />
            </div>
            <FormInputField control={form.control} label="Tagline" name="tagline" />

            <FormField
              control={form.control}
              name="features"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Features (one per line)</FormLabel>
                  <FormControl>
                    <Textarea rows={6} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormSwitchField
              control={form.control}
              description="A disabled CTA reads 'Coming soon' and links nowhere — use this until checkout exists for the tier."
              label="CTA disabled (no billing yet)"
              name="cta_disabled"
            />
            <FormInputField control={form.control} label="CTA label" name="cta_label" placeholder="Start learning free / Coming soon" />
            {ctaEnabled && (
              <FormInputField control={form.control} label="CTA link" name="cta_href" placeholder="/register" />
            )}
            <FormSwitchField
              control={form.control}
              description={'Shows a "Most popular" badge and a highlighted border.'}
              label="Highlighted"
              name="highlighted"
            />

            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Saving…" : "Save changes"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
