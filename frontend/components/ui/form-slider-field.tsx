"use client";

import type { Control, FieldPath, FieldValues } from "react-hook-form";

import {
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Slider } from "@/components/ui/slider";

interface FormSliderFieldProps<TValues extends FieldValues> {
  control: Control<TValues>;
  name: FieldPath<TValues>;
  label: string;
  min?: number;
  max?: number;
  step?: number;
  description?: string;
  serverError?: string;
}

export function FormSliderField<TValues extends FieldValues>({
  control,
  name,
  label,
  min = 0,
  max = 10,
  step = 1,
  description,
  serverError,
}: FormSliderFieldProps<TValues>) {
  return (
    <FormField
      control={control}
      name={name}
      render={({ field }) => (
        <FormItem>
          <FormLabel>
            {label} — {field.value ?? min}
          </FormLabel>
          <FormControl>
            <Slider
              max={max}
              min={min}
              step={step}
              value={[field.value ?? min]}
              onValueChange={([v]) => field.onChange(v)}
            />
          </FormControl>
          {description && <FormDescription>{description}</FormDescription>}
          <FormMessage>{serverError}</FormMessage>
        </FormItem>
      )}
    />
  );
}
