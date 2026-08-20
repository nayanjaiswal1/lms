"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Check, ExternalLink, ThumbsUp, Trash2 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Textarea } from "@/components/ui/textarea";
import {
  deleteProposalAction,
  removeVoteAction,
  submitProposalAction,
  voteForProposalAction,
} from "@/app/(app)/projects/actions";
import type { DesignProposalView } from "@/lib/projects/types";

const Schema = z.object({
  title: z.string().min(2, "Title is too short."),
  description: z.string().optional(),
  link: z.string().optional(),
});
type FormData = z.infer<typeof Schema>;

interface DesignProposalPanelProps {
  proposals: DesignProposalView[];
  checkpointId: string;
  teamId: string;
  currentUserId: string;
}

// Team-member view of a design/architecture review checkpoint: submit a
// proposal, vote on teammates' proposals, see which one staff accepted.
// Accepting itself is staff-only (design-proposal-staff-panel.tsx).
export function DesignProposalPanel({ proposals, checkpointId, teamId, currentUserId }: DesignProposalPanelProps) {
  const router = useRouter();
  const [pendingId, setPendingId] = React.useState<string | null>(null);
  const form = useForm<FormData>({ resolver: zodResolver(Schema), defaultValues: { title: "", description: "", link: "" } });

  const onSubmit = async (data: FormData) => {
    const result = await submitProposalAction(teamId, checkpointId, {
      title: data.title,
      description: data.description?.trim() || null,
      link: data.link?.trim() || null,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Proposal submitted.");
    form.reset();
    router.refresh();
  };

  async function handleVoteToggle(proposal: DesignProposalView) {
    setPendingId(proposal.id);
    const result = proposal.my_vote
      ? await removeVoteAction(proposal.id, teamId)
      : await voteForProposalAction(proposal.id, teamId);
    setPendingId(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    router.refresh();
  }

  async function handleDelete(proposalId: string) {
    setPendingId(proposalId);
    const result = await deleteProposalAction(proposalId, teamId);
    setPendingId(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Proposal withdrawn.");
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-3">
      {proposals.length === 0 ? (
        <p className="text-sm text-muted-foreground">No proposals yet — be the first to submit one.</p>
      ) : (
        <ul className="divide-y divide-border rounded-md border border-border">
          {proposals.map((p) => (
            <li className="flex flex-wrap items-center justify-between gap-2 px-3 py-2.5 text-sm" key={p.id}>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5">
                  <span className="font-medium">{p.title}</span>
                  {p.link && (
                    <a className="text-muted-foreground hover:text-foreground" href={p.link} rel="noreferrer" target="_blank">
                      <ExternalLink aria-hidden className="h-3 w-3" />
                    </a>
                  )}
                  {p.is_accepted && (
                    <Badge>
                      <Check aria-hidden className="mr-1 h-3 w-3" />
                      Accepted
                    </Badge>
                  )}
                </div>
                {p.description && <p className="truncate text-xs text-muted-foreground">{p.description}</p>}
              </div>
              <Button
                disabled={pendingId === p.id}
                size="sm"
                variant={p.my_vote ? "default" : "outline"}
                onClick={() => handleVoteToggle(p)}
              >
                <ThumbsUp aria-hidden className="mr-1.5 h-3.5 w-3.5" />
                {p.vote_count}
              </Button>
              {p.submitted_by === currentUserId && (
                <Button
                  aria-label="Withdraw proposal"
                  disabled={pendingId === p.id}
                  size="icon"
                  variant="ghost"
                  onClick={() => handleDelete(p.id)}
                >
                  <Trash2 aria-hidden className="h-3.5 w-3.5 text-destructive" />
                </Button>
              )}
            </li>
          ))}
        </ul>
      )}

      <Form {...form}>
        <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
          <FormInputField control={form.control} label="Proposal title" name="title" placeholder="REST over GraphQL for v1" />
          <FormField
            control={form.control}
            name="description"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Why (optional)</FormLabel>
                <FormControl>
                  <Textarea rows={2} {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormInputField control={form.control} label="Link (optional)" name="link" placeholder="Figma, doc, or diagram URL" />
          <Button className="self-end" disabled={form.formState.isSubmitting} size="sm" type="submit">
            {form.formState.isSubmitting ? "Submitting…" : "Submit proposal"}
          </Button>
        </form>
      </Form>
    </div>
  );
}
