"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { PlusCircle } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { createReleaseAction } from "@/lib/workspace/phase5-actions";

const Schema = z.object({
  version: z.string().min(1, "Required.").max(40),
  target_at: z.string().optional(),
});
type FormData = z.infer<typeof Schema>;

export function CreateReleaseDialog({ workspaceId }: { workspaceId: string }) {
  const [open, setOpen] = useState(false);
  const form = useForm<FormData>({ resolver: zodResolver(Schema), defaultValues: { version: "", target_at: "" } });

  async function onSubmit(data: FormData) {
    const result = await createReleaseAction(workspaceId, {
      version: data.version,
      target_at: data.target_at ? new Date(data.target_at).toISOString() : null,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Release created.");
    setOpen(false);
    form.reset({ version: "", target_at: "" });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <PlusCircle aria-hidden className="h-4 w-4" />
          New release
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader><DialogTitle>New release</DialogTitle></DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormField
              control={form.control}
              name="version"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Version</FormLabel>
                  <FormControl><Input {...field} placeholder="v1.2" /></FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="target_at"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Target date (optional)</FormLabel>
                  <FormControl><Input {...field} type="date" /></FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Creating…" : "Create"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
