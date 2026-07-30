"use client";

import { Plus } from "lucide-react";
import { parseAsBoolean, useQueryState } from "nuqs";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { createTeamAction } from "@/app/(app)/projects/actions";

const Schema = z.object({
  name: z.string().min(2, "Name is too short."),
  slug: z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, "Use lowercase letters, numbers, and hyphens only."),
});
type FormData = z.infer<typeof Schema>;

interface CreateTeamPanelProps {
  assignmentId: string;
}

export function CreateTeamPanel({ assignmentId }: CreateTeamPanelProps) {
  const [open, setOpen] = useQueryState("create-team", parseAsBoolean.withDefault(false));
  const router = useRouter();
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { name: "", slug: "" },
  });

  const onSubmit = async (data: FormData) => {
    const res = await createTeamAction(assignmentId, data);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Team created.");
    form.reset();
    void setOpen(false);
    router.refresh();
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm">
          <Plus aria-hidden className="mr-1.5 h-4 w-4" />
          Create team
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Create team</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Team name" name="name" placeholder="Team Byte Bandits" />
            <FormInputField control={form.control} label="Slug" name="slug" placeholder="team-byte-bandits" />
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Creating…" : "Create team"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
