"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { createRecipeAction } from "@/lib/labs/builder/actions";
import type { TargetPlacement } from "@/lib/labs/builder/types";
import ROUTES from "@/lib/routes";

const NewRecipeSchema = z.object({
  title: z.string().trim().min(1, "Give the lab a title").max(200),
  appVersionId: z.string().min(1, "Pick a base app"),
});
type NewRecipeValues = z.infer<typeof NewRecipeSchema>;

interface NewRecipeFormProps {
  appOptions: { label: string; value: string }[];
  placement: TargetPlacement | null;
}

export function NewRecipeForm({ appOptions, placement }: NewRecipeFormProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const form = useForm<NewRecipeValues>({
    resolver: zodResolver(NewRecipeSchema),
    defaultValues: { title: "", appVersionId: appOptions.length === 1 ? appOptions[0].value : "" },
  });

  const onSubmit = (values: NewRecipeValues) =>
    startTransition(async () => {
      const res = await createRecipeAction({ ...values, placement });
      if (!res.ok || !res.data) {
        toast.error(res.error ?? "Could not create the lab.");
        return;
      }
      router.push(ROUTES.labBuilderRecipe(res.data.id, "fault"));
    });

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Title" name="title" placeholder="Order list is slow in production" />
        <FormSelectField
          control={form.control}
          description="Only stacks with a published base app are listed."
          label="Base app"
          name="appVersionId"
          options={appOptions}
          placeholder="Choose an app"
        />
        <Button className="self-start" disabled={pending} type="submit">
          Create and choose a fault
        </Button>
      </form>
    </Form>
  );
}
