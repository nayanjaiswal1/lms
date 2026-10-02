"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { useSaveSpec, type RecipeRef } from "@/components/labs/builder/use-save-spec";
import { fromFieldString, isRandomizable, toFieldString, type ParamField } from "@/lib/labs/builder/params";
import { paramsOf, withParam } from "@/lib/labs/builder/spec";

/** Select value meaning "not set" (a Radix Select item can't be ""). */
const UNSET = "__unset";

interface ParamEditorProps {
  recipe: RecipeRef;
  versionId: string;
  fields: ParamField[];
}

function schemaFor(fields: ParamField[]) {
  return z.record(z.string(), z.string()).superRefine((values, ctx) => {
    for (const f of fields) {
      try {
        fromFieldString(f, values[f.name] === UNSET ? "" : (values[f.name] ?? ""));
      } catch (e) {
        ctx.addIssue({ code: "custom", path: [f.name], message: e instanceof Error ? e.message : "Invalid value" });
      }
    }
  });
}

/** Edits one selected block's parameters. Empty = the block default, or a variant axis if randomizable. */
export function ParamEditor({ recipe, versionId, fields }: ParamEditorProps) {
  const { save, pending } = useSaveSpec(recipe);
  const current = paramsOf(recipe.spec, versionId);
  const form = useForm<Record<string, string>>({
    resolver: zodResolver(schemaFor(fields)),
    defaultValues: Object.fromEntries(
      fields.map((f) => [f.name, toFieldString(f, current[f.name]) || (f.control === "choice" ? UNSET : "")]),
    ),
  });

  const onSubmit = (values: Record<string, string>) => {
    let spec = recipe.spec;
    for (const f of fields) {
      const raw = values[f.name] === UNSET ? "" : (values[f.name] ?? "");
      spec = withParam(spec, versionId, f.name, fromFieldString(f, raw));
    }
    save(spec, "Parameters saved");
  };

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        {fields.map((f) => {
          const description = [f.schema.description, isRandomizable(f.schema) ? "Leave empty to vary it across variants." : ""]
            .filter(Boolean)
            .join(" ");
          if (f.control === "choice") {
            const options = [{ label: "Default", value: UNSET }, ...f.choices.map((c) => ({ label: c, value: c }))];
            return <FormSelectField control={form.control} description={description} key={f.name} label={f.name} name={f.name} options={options} />;
          }
          if (f.control === "json" || f.control === "markdown") {
            return (
              <FormTextareaField
                className={f.control === "json" ? "font-mono text-xs" : undefined}
                control={form.control}
                description={description}
                key={f.name}
                label={f.name}
                name={f.name}
                rows={f.control === "json" ? 8 : 4}
              />
            );
          }
          return (
            <FormInputField
              control={form.control}
              description={description}
              key={f.name}
              label={f.name}
              name={f.name}
              type={f.control === "number" ? "number" : "text"}
            />
          );
        })}
        <Button className="self-start" disabled={pending} type="submit" variant="outline">
          Save parameters
        </Button>
      </form>
    </Form>
  );
}
