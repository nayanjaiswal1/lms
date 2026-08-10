"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { RotateCcw } from "lucide-react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { TagInput } from "@/components/ui/tag-input";
import { HABIT_ICON_OPTIONS, HABIT_ICONS, MAX_CUSTOM_ICON_LENGTH } from "@/lib/habits/icons";
import type { Habit } from "@/lib/server/habits";
import { cn } from "@/lib/utils";

const Schema = z.object({
  icon: z.string().max(MAX_CUSTOM_ICON_LENGTH, "Keep it short — one emoji is best"),
  tags: z.array(z.string().trim().min(1).max(24)).max(6, "At most 6 tags"),
});
type FormData = z.infer<typeof Schema>;

interface HabitCustomizeDialogProps {
  habit: Habit;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (icon: string, tags: string[]) => Promise<boolean>;
}

// Icon + tags editor — the only place either attribute is changed, reached
// from the grid row's Actions menu. Color keeps its own always-visible
// picker (Wheel view); these two are edited less often so a dialog fits
// better than another persistent on-row control.
export function HabitCustomizeDialog({ habit, open, onOpenChange, onSave }: HabitCustomizeDialogProps) {
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    values: { icon: habit.icon, tags: habit.tags },
  });
  const icon = form.watch("icon");

  async function onSubmit(data: FormData) {
    const ok = await onSave(data.icon, data.tags);
    if (ok) onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Customize {habit.name}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="flex flex-col gap-4" onSubmit={form.handleSubmit(onSubmit)}>
            <FormField
              control={form.control}
              name="icon"
              render={() => (
                <FormItem>
                  <FormLabel>Icon</FormLabel>
                  <FormControl>
                    <div className="flex flex-col gap-2">
                      <div className="grid grid-cols-6 gap-1.5">
                        <button
                          aria-label="Use default icon"
                          aria-pressed={icon === ""}
                          className={cn(
                            "touch-target flex items-center justify-center rounded-md border border-border text-muted-foreground hover:bg-accent",
                            icon === "" && "border-primary bg-primary/10 text-primary",
                          )}
                          type="button"
                          onClick={() => form.setValue("icon", "")}
                        >
                          <RotateCcw aria-hidden className="size-4" />
                        </button>
                        {HABIT_ICON_OPTIONS.map((opt) => (
                          <button
                            aria-label={opt.value}
                            aria-pressed={icon === opt.value}
                            className={cn(
                              "touch-target flex items-center justify-center rounded-md border border-border hover:bg-accent",
                              icon === opt.value && "border-primary bg-primary/10 text-primary",
                            )}
                            key={opt.value}
                            type="button"
                            onClick={() => form.setValue("icon", opt.value)}
                          >
                            <opt.Icon aria-hidden className="size-4" />
                          </button>
                        ))}
                      </div>
                      <div className="flex items-center gap-2">
                        <Input
                          className="w-20 text-center text-lg"
                          maxLength={MAX_CUSTOM_ICON_LENGTH}
                          placeholder="✨"
                          value={icon && !HABIT_ICONS[icon] ? icon : ""}
                          onChange={(e) => form.setValue("icon", e.target.value, { shouldValidate: true })}
                        />
                        <span className="text-xs text-muted-foreground">
                          Or type/paste your own emoji — tap the field for your keyboard&apos;s emoji picker.
                        </span>
                      </div>
                    </div>
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="tags"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Tags</FormLabel>
                  <FormControl>
                    <TagInput placeholder="fitness, morning, ..." value={field.value} onChange={field.onChange} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                Save
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
