"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { TextBlockFields } from "@/components/labs/builder/text-block-fields";
import { createTextBlockAction, updateTextBlockAction } from "@/lib/labs/builder/actions";
import {
  emptyValues,
  textBlockSchema,
  toManifest,
  toValues,
  type TextBlockValues,
} from "@/lib/labs/builder/text-blocks";
import type { BlockManifest, TextBlockKind } from "@/lib/labs/builder/types";
import ROUTES from "@/lib/routes";

interface TextBlockFormProps {
  kind: TextBlockKind;
  /** Set when editing: saving appends a new immutable version of this block. */
  existing?: { blockId: string; manifest: BlockManifest };
}

export function TextBlockForm({ kind, existing }: TextBlockFormProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const form = useForm<TextBlockValues>({
    resolver: zodResolver(textBlockSchema(kind)),
    defaultValues: existing ? toValues(existing.manifest) : emptyValues(),
  });

  const onSubmit = (values: TextBlockValues) =>
    startTransition(async () => {
      const manifest = toManifest(kind, values);
      const res = existing
        ? await updateTextBlockAction(existing.blockId, manifest)
        : await createTextBlockAction(manifest);
      if (!res.ok || !res.data) {
        toast.error(res.error ?? "Could not save the block.");
        return;
      }
      toast.success(existing ? "New version saved" : "Block created");
      router.push(ROUTES.labBuilderBlock(res.data.block_id));
    });

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Title" name="title" />
        <FormInputField control={form.control} label="Summary" name="summary" />
        <TextBlockFields control={form.control} kind={kind} />
        {existing && (
          <FormInputField
            control={form.control}
            description="Shown as 'update available' to recipes that use the previous version."
            label="What changed"
            name="changelog"
          />
        )}
        <Button className="self-start" disabled={pending} type="submit">
          {existing ? "Save new version" : "Create block"}
        </Button>
      </form>
    </Form>
  );
}
