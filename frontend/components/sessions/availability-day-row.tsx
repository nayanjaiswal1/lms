"use client";

import type { Control } from "react-hook-form";

import { FormControl, FormField, FormItem, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { SESSION_SLOT_LENGTH_OPTIONS } from "@/lib/constants";
import type { AvailabilityFormData } from "./weekly-availability-editor";

interface AvailabilityDayRowProps {
  control: Control<AvailabilityFormData>;
  index: number;
  label: string;
}

/** One weekday's row in the weekly grid: enable toggle, start/end time, slot length. */
export function AvailabilityDayRow({ control, index, label }: AvailabilityDayRowProps) {
  return (
    <div className="grid grid-cols-1 items-start gap-3 rounded-md border border-border p-4 sm:grid-cols-[3rem_6rem_1fr_1fr_9rem] sm:items-center">
      <FormField
        control={control}
        name={`rules.${index}.active`}
        render={({ field }) => (
          <FormItem className="flex flex-row items-center">
            <FormControl>
              <Switch aria-label={`Enable ${label}`} checked={field.value} onCheckedChange={field.onChange} />
            </FormControl>
          </FormItem>
        )}
      />
      <p className="text-sm font-medium">{label}</p>
      <FormField
        control={control}
        name={`rules.${index}.start_time`}
        render={({ field }) => (
          <FormItem>
            <FormControl>
              <Input aria-label={`${label} start time`} type="time" {...field} />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />
      <FormField
        control={control}
        name={`rules.${index}.end_time`}
        render={({ field }) => (
          <FormItem>
            <FormControl>
              <Input aria-label={`${label} end time`} type="time" {...field} />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />
      <FormField
        control={control}
        name={`rules.${index}.slot_minutes`}
        render={({ field }) => (
          <FormItem>
            <Select value={field.value} onValueChange={field.onChange}>
              <FormControl>
                <SelectTrigger aria-label={`${label} slot length`}>
                  <SelectValue />
                </SelectTrigger>
              </FormControl>
              <SelectContent>
                {SESSION_SLOT_LENGTH_OPTIONS.map((opt) => (
                  <SelectItem key={opt.value} value={opt.value}>
                    {opt.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <FormMessage />
          </FormItem>
        )}
      />
    </div>
  );
}
