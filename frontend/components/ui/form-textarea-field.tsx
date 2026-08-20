"use client";

import type { ComponentProps } from "react";
import type { Control, FieldPath, FieldValues } from "react-hook-form";

import {
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Textarea } from "@/components/ui/textarea";

interface FormTextareaFieldProps<TValues extends FieldValues>
  extends Omit<ComponentProps<typeof Textarea>, "name"> {
  control: Control<TValues>;
  name: FieldPath<TValues>;
  label?: string;
  description?: string;
  serverError?: string;
}

export function FormTextareaField<TValues extends FieldValues>({
  control,
  name,
  label,
  description,
  serverError,
  ...textareaProps
}: FormTextareaFieldProps<TValues>) {
  return (
    <FormField
      control={control}
      name={name}
      render={({ field }) => (
        <FormItem>
          {label && <FormLabel>{label}</FormLabel>}
          <FormControl>
            <Textarea {...textareaProps} {...field} />
          </FormControl>
          {description && <FormDescription>{description}</FormDescription>}
          <FormMessage>{serverError}</FormMessage>
        </FormItem>
      )}
    />
  );
}
