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
import { Input } from "@/components/ui/input";
import { PasswordInput } from "@/components/ui/password-input";

interface FormInputFieldProps<TValues extends FieldValues>
  extends Omit<ComponentProps<typeof Input>, "name"> {
  control: Control<TValues>;
  name: FieldPath<TValues>;
  label: string;
  description?: string;
  serverError?: string;
}

export function FormInputField<TValues extends FieldValues>({
  control,
  name,
  label,
  description,
  serverError,
  type,
  ...inputProps
}: FormInputFieldProps<TValues>) {
  return (
    <FormField
      control={control}
      name={name}
      render={({ field }) => (
        <FormItem>
          <FormLabel>{label}</FormLabel>
          <FormControl>
            {type === "password" ? (
              <PasswordInput type={type} {...inputProps} {...field} />
            ) : (
              <Input type={type} {...inputProps} {...field} />
            )}
          </FormControl>
          {description && <FormDescription>{description}</FormDescription>}
          <FormMessage>{serverError}</FormMessage>
        </FormItem>
      )}
    />
  );
}
