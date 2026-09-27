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
import { createSprintAction } from "@/lib/workspace/phase5-actions";

const Schema = z.object({
  name: z.string().min(1, "Required.").max(80),
  starts_on: z.string().min(1, "Required."),
  ends_on: z.string().min(1, "Required."),
});
type FormData = z.infer<typeof Schema>;

export function CreateSprintDialog({ workspaceId }: { workspaceId: string }) {
  const [open, setOpen] = useState(false);
  const form = useForm<FormData>({ resolver: zodResolver(Schema), defaultValues: { name: "", starts_on: "", ends_on: "" } });

  async function onSubmit(data: FormData) {
    const result = await createSprintAction(workspaceId, data);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Sprint created.");
    setOpen(false);
    form.reset({ name: "", starts_on: "", ends_on: "" });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <PlusCircle aria-hidden className="h-4 w-4" />
          New sprint
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader><DialogTitle>New sprint</DialogTitle></DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormField
              control={form.control}
              name="name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Name</FormLabel>
                  <FormControl><Input {...field} placeholder="Sprint 1" /></FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="starts_on"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Starts on</FormLabel>
                  <FormControl><Input {...field} type="date" /></FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="ends_on"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Ends on</FormLabel>
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
