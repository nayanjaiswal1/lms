"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { UserPlus } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { addMemberAction } from "@/lib/workspace/actions";

const Schema = z.object({
  email: z.string().email("Enter a valid email."),
  role: z.enum(["member", "viewer", "manager"]),
});
type FormData = z.infer<typeof Schema>;

interface AddMemberDialogProps {
  workspaceId: string;
  /** Only the owner may grant the manager role (see 02-auth-security.md §3). */
  canGrantManager: boolean;
}

const ROLE_OPTIONS = [
  { label: "Member", value: "member" },
  { label: "Viewer", value: "viewer" },
  { label: "Manager", value: "manager" },
] as const;

export function AddMemberDialog({ workspaceId, canGrantManager }: AddMemberDialogProps) {
  const [open, setOpen] = useState(false);
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { email: "", role: "member" },
  });
  const options = canGrantManager ? ROLE_OPTIONS : ROLE_OPTIONS.filter((o) => o.value !== "manager");

  async function onSubmit(data: FormData) {
    const result = await addMemberAction(workspaceId, data);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${data.email} added — they'll see an in-app invite to accept.`);
    setOpen(false);
    form.reset();
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <UserPlus aria-hidden className="h-4 w-4" />
          Add member
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Add a member</DialogTitle>
          <DialogDescription>
            The email must belong to an existing member of this organization. They&apos;ll get an in-app invite to accept.
          </DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Email" name="email" placeholder="teammate@org.com" type="email" />
            <FormSelectField control={form.control} label="Role" name="role" options={options} />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Adding…" : "Add member"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
