"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { DEBUG_UI_MODE, DEBUG_UI_OPTIONS } from "@/lib/constants";
import { saveLabSettingsAction, type LabSettings } from "@/app/org/settings/labs/actions";

const Schema = z.object({
  debug_ui: z.enum([DEBUG_UI_MODE.OLD, DEBUG_UI_MODE.NEW]),
});
type FormData = z.infer<typeof Schema>;

interface LabSettingsFormProps {
  settings: LabSettings;
}

export function LabSettingsForm({ settings }: LabSettingsFormProps) {
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { debug_ui: settings.debug_ui },
  });

  const onSubmit = async (data: FormData) => {
    const res = await saveLabSettingsAction(data);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Lab settings saved.");
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormSelectField
          control={form.control}
          description="Takes effect the next time a debug lab workspace opens. Mission mode also records tab-away time, large pastes and opened files for each attempt."
          label="Debug lab interface"
          name="debug_ui"
          options={DEBUG_UI_OPTIONS}
        />
        <div className="flex justify-end">
          <Button disabled={form.formState.isSubmitting} type="submit">
            {form.formState.isSubmitting ? "Saving…" : "Save"}
          </Button>
        </div>
      </form>
    </Form>
  );
}
