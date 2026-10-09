"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { TagInput } from "@/components/ui/tag-input";
import { WithdrawInterestButton } from "@/components/workspace/withdraw-interest-button";
import { registerWorkspaceInterestAction } from "@/lib/workspace/discover-actions";

const Schema = z.object({
  skills: z.array(z.string().max(40)).max(15, "Up to 15 skills."),
  portfolio_url: z
    .string()
    .max(500)
    .refine((v) => v === "" || /^https?:\/\//i.test(v), "Must start with http:// or https://."),
  message: z.string().max(2000),
});
type FormData = z.infer<typeof Schema>;

interface ApplyInterestPanelProps {
  workspaceId: string;
  hasApplied: boolean;
}

export function ApplyInterestPanel({ workspaceId, hasApplied }: ApplyInterestPanelProps) {
  const [open, setOpen] = useState(false);
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { skills: [], portfolio_url: "", message: "" },
  });

  async function onSubmit(data: FormData) {
    const result = await registerWorkspaceInterestAction(workspaceId, {
      skills: data.skills,
      portfolio_url: data.portfolio_url || undefined,
      message: data.message || undefined,
    });
    if (result.error) {
      form.setError("root", { message: result.error });
      return;
    }
    toast.success("Interest submitted.");
    setOpen(false);
  }

  if (hasApplied) {
    return (
      <div className="flex items-center gap-3">
        <span className="text-sm text-muted-foreground">You&apos;ve registered interest.</span>
        <WithdrawInterestButton workspaceId={workspaceId} />
      </div>
    );
  }

  if (!open) {
    return (
      <Button className="self-start" size="sm" onClick={() => setOpen(true)}>
        I&apos;m interested
      </Button>
    );
  }

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="skills"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Skills (optional)</FormLabel>
              <FormControl>
                <TagInput placeholder="Add a skill and press Enter…" value={field.value} onChange={field.onChange} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormInputField
          control={form.control}
          label="Portfolio link (optional)"
          name="portfolio_url"
          placeholder="https://github.com/you"
        />
        <FormTextareaField control={form.control} label="Why this project? (optional)" name="message" rows={4} />
        {form.formState.errors.root && (
          <p className="text-sm text-destructive" role="alert">
            {form.formState.errors.root.message}
          </p>
        )}
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
            Cancel
          </Button>
          <Button disabled={form.formState.isSubmitting} type="submit">
            {form.formState.isSubmitting ? "Sending…" : "Send interest"}
          </Button>
        </div>
      </form>
    </Form>
  );
}
