"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Ban } from "lucide-react";
import { toast } from "sonner";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { getAffectedLabsAction, yankVersionAction } from "@/lib/labs/builder/actions";
import type { AffectedLab } from "@/lib/labs/builder/types";

/** Mirrors labauthor maxYankReason. */
const YankSchema = z.object({ reason: z.string().trim().min(1, "Say why it is being yanked").max(500) });
type YankValues = z.infer<typeof YankSchema>;

interface YankVersionButtonProps {
  blockId: string;
  versionId: string;
  version: string;
}

/** Platform super_admin only: blocks new builds from a version. Published labs keep running; the dialog lists them first. */
export function YankVersionButton({ blockId, versionId, version }: YankVersionButtonProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [labs, setLabs] = useState<AffectedLab[] | null>(null);
  const form = useForm<YankValues>({ resolver: zodResolver(YankSchema), defaultValues: { reason: "" } });

  const preview = () =>
    startTransition(async () => {
      const res = await getAffectedLabsAction(versionId);
      if (!res.ok || !res.data) {
        toast.error(res.error ?? "Could not load the affected labs.");
        return;
      }
      setLabs(res.data.affected_labs);
    });

  const confirm = (values: YankValues) =>
    startTransition(async () => {
      const res = await yankVersionAction(blockId, versionId, values.reason);
      if (!res.ok) {
        toast.error(res.error ?? "Could not yank the version.");
        return;
      }
      toast.success(`Version ${version} yanked`);
      setLabs(null);
      router.refresh();
    });

  return (
    <>
      <Button disabled={pending} size="sm" type="button" variant="outline" onClick={preview}>
        <Ban aria-hidden className="mr-2 h-4 w-4" />
        Yank
      </Button>
      <Dialog open={labs !== null} onOpenChange={(open) => !open && setLabs(null)}>
        <DialogContent className="modal-responsive">
          <DialogHeader>
            <DialogTitle>Yank version {version}?</DialogTitle>
            <DialogDescription>
              New builds can no longer use it, and recipes pinned to it must move to another version. Published labs keep
              running as they are.
            </DialogDescription>
          </DialogHeader>
          {labs && labs.length > 0 ? (
            <div className="flex flex-col gap-1 text-sm">
              <p className="font-semibold">
                {labs.length} published lab{labs.length === 1 ? "" : "s"} built from it:
              </p>
              <ul className="list-disc pl-5 text-muted-foreground">
                {labs.map((l) => (
                  <li key={l.id}>{l.title}</li>
                ))}
              </ul>
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">No published lab was built from this version.</p>
          )}
          <Form {...form}>
            <form className="form-stack" onSubmit={form.handleSubmit(confirm)}>
              <FormTextareaField control={form.control} label="Reason" name="reason" rows={3} />
              <DialogFooter>
                <Button disabled={pending} type="submit" variant="destructive">
                  Yank version
                </Button>
              </DialogFooter>
            </form>
          </Form>
        </DialogContent>
      </Dialog>
    </>
  );
}
