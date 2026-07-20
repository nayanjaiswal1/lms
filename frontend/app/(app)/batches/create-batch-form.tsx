"use client";

import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { createBatchAction } from "@/app/(app)/batches/actions";
import { useTerminology } from "@/lib/terminology-context";

const Schema = z.object({
  name: z.string().min(2, "Name is too short."),
  description: z.string().optional(),
});
type FormData = z.infer<typeof Schema>;

interface CreateBatchFormProps {
  onCreated: () => void;
}

export function CreateBatchForm({ onCreated }: CreateBatchFormProps) {
  const router = useRouter();
  const t = useTerminology();
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { name: "", description: "" },
  });

  const onSubmit = async (data: FormData) => {
    const res = await createBatchAction({ name: data.name, description: data.description });
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success(`${t.class_} created.`);
    form.reset();
    onCreated();
    router.refresh();
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label={`${t.class_} name`} name="name" placeholder="Cohort 2026 — Backend" />
        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Description</FormLabel>
              <FormControl>
                <Textarea placeholder="Optional…" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Creating…" : `Create ${t.class_.toLowerCase()}`}
        </Button>
      </form>
    </Form>
  );
}
