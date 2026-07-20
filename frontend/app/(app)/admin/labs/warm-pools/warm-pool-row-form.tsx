"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { FormInputField } from "@/components/ui/form-input-field";
import { WARM_POOL_MODE, WARM_POOL_MODE_OPTIONS } from "@/lib/constants";
import { updateWarmPoolConfigAction } from "./actions";

const Schema = z.object({
  mode: z.enum([WARM_POOL_MODE.AUTO, WARM_POOL_MODE.FIXED, WARM_POOL_MODE.OFF]),
  fixed_size: z.coerce.number().int().min(0).max(20),
  max_size: z.coerce.number().int().min(0).max(20),
});
type FormInput = z.input<typeof Schema>;
type FormData = z.output<typeof Schema>;

interface WarmPoolRowFormProps {
  labId: string;
  mode: string;
  fixedSize: number;
  maxSize: number;
}

export function WarmPoolRowForm({ labId, mode, fixedSize, maxSize }: WarmPoolRowFormProps) {
  const form = useForm<FormInput, unknown, FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { mode: mode as FormInput["mode"], fixed_size: fixedSize, max_size: maxSize },
  });

  const onSubmit = async (data: FormData) => {
    const result = await updateWarmPoolConfigAction(labId, data);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Warm pool config updated.");
  };

  return (
    <Form {...form}>
      <form className="flex flex-wrap items-end gap-3" onSubmit={form.handleSubmit(onSubmit)}>
        <div className="w-full sm:w-40">
          <FormSelectField control={form.control} name="mode" label="Mode" options={WARM_POOL_MODE_OPTIONS} />
        </div>
        <div className="w-full sm:w-24">
          <FormInputField control={form.control} name="fixed_size" label="Fixed size" type="number" min={0} max={20} />
        </div>
        <div className="w-full sm:w-24">
          <FormInputField control={form.control} name="max_size" label="Max size" type="number" min={0} max={20} />
        </div>
        <Button disabled={form.formState.isSubmitting} size="sm" type="submit">
          {form.formState.isSubmitting ? "Saving…" : "Save"}
        </Button>
      </form>
    </Form>
  );
}
