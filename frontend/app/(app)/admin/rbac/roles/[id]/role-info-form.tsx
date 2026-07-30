"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Pencil } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { updateRoleAction } from "@/app/(app)/admin/rbac/roles/actions";

const Schema = z.object({
  name: z.string().min(2, "Name is too short.").max(80),
  description: z.string().max(255).optional(),
});
type FormData = z.infer<typeof Schema>;

interface Props {
  roleId: string;
  name: string;
  description: string;
  canEdit: boolean;
  badges?: React.ReactNode;
  onSaved: (next: { name: string; description: string }) => void;
}

export function RoleInfoForm({ roleId, name, description, canEdit, badges, onSaved }: Props) {
  const [isEditing, setIsEditing] = useState(false);
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { name, description },
  });

  if (!canEdit || !isEditing) {
    return (
      <div className="flex items-start gap-2">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="page-title">{name}</h1>
            {badges}
          </div>
          <p className="text-muted-foreground mt-1">{description}</p>
        </div>
        {canEdit && (
          <Button
            aria-label="Edit role name and description"
            className="touch-target"
            size="icon"
            variant="ghost"
            onClick={() => {
              form.reset({ name, description });
              setIsEditing(true);
            }}
          >
            <Pencil className="h-4 w-4" />
          </Button>
        )}
      </div>
    );
  }

  const onSubmit = async (data: FormData) => {
    const res = await updateRoleAction(roleId, {
      name: data.name.trim(),
      description: data.description?.trim(),
    });
    if (res.error || !res.data) {
      toast.error(res.error ?? "Failed to update role.");
      return;
    }
    toast.success("Role updated.");
    onSaved({ name: res.data.role.name, description: res.data.role.description });
    setIsEditing(false);
  };

  return (
    <Form {...form}>
      <form className="form-stack w-full sm:max-w-md" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Role name" name="name" />
        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Description</FormLabel>
              <FormControl>
                <Textarea rows={2} {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <div className="flex gap-2">
          <Button disabled={form.formState.isSubmitting} type="submit">
            {form.formState.isSubmitting ? "Saving…" : "Save"}
          </Button>
          <Button type="button" variant="ghost" onClick={() => setIsEditing(false)}>
            Cancel
          </Button>
        </div>
      </form>
    </Form>
  );
}
