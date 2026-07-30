"use client";

import { useRouter } from "next/navigation";
import { useQueryState, parseAsBoolean } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { createRoleAction } from "@/app/(app)/admin/rbac/roles/actions";

const Schema = z.object({
  name: z.string().min(2, "Name is too short.").max(80),
  description: z.string().max(255).optional(),
});
type FormData = z.infer<typeof Schema>;

export function CreateRoleDialog() {
  const router = useRouter();
  const [open, setOpen] = useQueryState("modal", parseAsBoolean.withDefault(false));
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { name: "", description: "" },
  });

  const onSubmit = async (data: FormData) => {
    const res = await createRoleAction({ name: data.name.trim(), description: data.description?.trim() });
    if (res.error || !res.data) {
      toast.error(res.error ?? "Failed to create role.");
      return;
    }
    toast.success("Role created.");
    form.reset();
    void setOpen(false);
    router.push(`/admin/rbac/roles/${res.data.role.id}`);
  };

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      <DialogTrigger asChild>
        <Button>New Role</Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>New Role</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField
              control={form.control}
              label="Role name"
              name="name"
              placeholder="e.g. content-reviewer"
            />
            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description</FormLabel>
                  <FormControl>
                    <Textarea placeholder="What is this role for?" rows={3} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Creating…" : "Create Role"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
