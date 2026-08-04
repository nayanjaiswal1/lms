"use client";

import type { ReactNode } from "react";
import type { Control, FieldPath, FieldValues } from "react-hook-form";

import {
  FormControl,
  FormField,
  FormItem,
  FormMessage,
} from "@/components/ui/form";
import { Checkbox } from "@/components/ui/checkbox";

interface FormCheckboxFieldProps<TValues extends FieldValues> {
  control: Control<TValues>;
  name: FieldPath<TValues>;
  label: ReactNode;
  disabled?: boolean;
  serverError?: string;
}

export function FormCheckboxField<TValues extends FieldValues>({
  control,
  name,
  label,
  disabled,
  serverError,
}: FormCheckboxFieldProps<TValues>) {
  return (
    <FormField
      control={control}
      name={name}
      render={({ field }) => (
        <FormItem>
          <div className="flex items-start gap-2.5">
            <FormControl>
              <Checkbox
                checked={field.value}
                className="mt-0.5"
                disabled={disabled}
                onCheckedChange={field.onChange}
              />
            </FormControl>
            <span className="text-sm leading-relaxed text-muted-foreground">{label}</span>
          </div>
          <FormMessage>{serverError}</FormMessage>
        </FormItem>
      )}
    />
  );
}
