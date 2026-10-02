"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Play } from "lucide-react";
import { toast } from "sonner";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { startPreviewAction } from "@/lib/labs/builder/actions";
import ROUTES from "@/lib/routes";

const PreviewSchema = z.object({ variantKey: z.string().min(1) });
type PreviewValues = z.infer<typeof PreviewSchema>;

interface PreviewLauncherProps {
  buildId: string;
  variantOptions: { label: string; value: string }[];
}

/** Starts an is_test session on a chosen variant of a verified build. */
export function PreviewLauncher({ buildId, variantOptions }: PreviewLauncherProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const form = useForm<PreviewValues>({
    resolver: zodResolver(PreviewSchema),
    defaultValues: { variantKey: variantOptions[0]?.value ?? "" },
  });

  const onSubmit = ({ variantKey }: PreviewValues) =>
    startTransition(async () => {
      const res = await startPreviewAction(buildId, variantKey);
      if (!res.ok || !res.data) {
        toast.error(res.error ?? "Could not start the preview.");
        return;
      }
      router.push(ROUTES.labSession(res.data.id));
    });

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        {variantOptions.length > 1 && (
          <FormSelectField control={form.control} label="Variant" name="variantKey" options={variantOptions} />
        )}
        <Button className="self-start" disabled={pending} type="submit">
          <Play aria-hidden className="h-4 w-4" />
          Preview as a student
        </Button>
      </form>
    </Form>
  );
}
