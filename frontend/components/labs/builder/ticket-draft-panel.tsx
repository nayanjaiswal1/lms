"use client";

import { useTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Sparkles } from "lucide-react";
import { toast } from "sonner";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { useSaveSpec, type RecipeRef } from "@/components/labs/builder/use-save-spec";
import { createTextBlockAction, draftTicketAction } from "@/lib/labs/builder/actions";
import { TICKET_PERSONA_OPTIONS } from "@/lib/labs/builder/options";
import { withBlock } from "@/lib/labs/builder/spec";

const DraftSchema = z.object({
  persona: z.string().min(1, "Pick a reporter voice"),
  title: z.string().trim().min(1, "Name the ticket block").max(200),
  body: z.string().trim().min(1, "Draft or write the ticket first").max(20000),
});
type DraftValues = z.infer<typeof DraftSchema>;

interface TicketDraftPanelProps {
  recipe: RecipeRef;
  /** The recipe's current ticket block version(s); the new ticket replaces them. */
  ticketVersionIds: string[];
  /** The server only drafts for a buildable composition (it feeds the faults' symptoms to the model). */
  canDraft: boolean;
  /** Whether the caller may save the result as an org ticket block. */
  canSave: boolean;
}

/** AI ticket drafting (docs/debug-labs.md B4 step 6). The server calls the model once per (composition, persona) and caches it. */
export function TicketDraftPanel({ recipe, ticketVersionIds, canDraft, canSave }: TicketDraftPanelProps) {
  const { save, pending: saving } = useSaveSpec(recipe);
  const [drafting, startDraft] = useTransition();
  const [creating, startCreate] = useTransition();
  const form = useForm<DraftValues>({
    resolver: zodResolver(DraftSchema),
    defaultValues: { persona: TICKET_PERSONA_OPTIONS[0].value, title: `${recipe.title} ticket`, body: "" },
  });

  const draft = () =>
    startDraft(async () => {
      const res = await draftTicketAction(recipe.id, form.getValues("persona"));
      if (!res.ok || !res.data) {
        toast.error(
          res.code === "rate_limited"
            ? "Too many drafts for now. Try again later, or write the ticket yourself."
            : (res.error ?? "Could not draft the ticket."),
        );
        return;
      }
      form.setValue("body", res.data.draft, { shouldValidate: true });
      if (res.data.cached) toast.info("Reused the saved draft for this composition and voice.");
    });

  const submitTicket = (values: DraftValues) =>
    startCreate(async () => {
      const res = await createTextBlockAction({
        kind: "ticket",
        title: values.title,
        summary: `Ticket in the voice of a ${values.persona}`,
        ticket: { template_md: values.body, persona: values.persona },
      });
      if (!res.ok || !res.data) {
        toast.error(
          res.code === "block_key_taken" ? "A ticket block with this title already exists. Pick another title." : (res.error ?? "Could not save the ticket."),
        );
        return;
      }
      save(withBlock(recipe.spec, res.data.version_id, ticketVersionIds), "Ticket added to the lab");
    });

  return (
    <section aria-label="Draft the ticket with AI" className="ai-surface flex flex-col gap-4">
      <span className="ai-badge inline-flex w-fit items-center gap-1">
        <Sparkles aria-hidden className="h-3.5 w-3.5" />
        AI
      </span>
      <p className="text-sm text-muted-foreground">
        Rewrites the fault&apos;s symptom as a ticket in the reporter&apos;s voice. It never sees the cause or the fix. Edit the
        draft freely before using it; placeholders like {"{{captured.trace}}"} are filled in at build time.
      </p>
      <Form {...form}>
        <form className="form-stack" onSubmit={form.handleSubmit(submitTicket)}>
          <FormSelectField control={form.control} label="Reporter voice" name="persona" options={TICKET_PERSONA_OPTIONS} />
          <Button
            className="self-start"
            disabled={!canDraft || drafting}
            type="button"
            variant="outline"
            onClick={draft}
          >
            {drafting ? "Drafting…" : "Draft with AI"}
          </Button>
          {!canDraft && (
            <p className="text-xs text-muted-foreground">Finish the earlier steps (the validation panel lists what is missing) to draft.</p>
          )}
          <FormTextareaField control={form.control} label="Ticket" name="body" rows={10} />
          {canSave ? (
            <>
              <FormInputField control={form.control} label="Save as block" name="title" />
              <Button className="self-start" disabled={creating || saving} type="submit">
                Use this ticket
              </Button>
            </>
          ) : (
            <p className="text-xs text-muted-foreground">Saving a ticket as a block needs the manage-blocks permission.</p>
          )}
        </form>
      </Form>
    </section>
  );
}
