"use client";

import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { saveSessionNotesAction, type SessionNotes } from "@/lib/server/sessions";

const NotesSchema = z.object({
  body: z.string().max(5000, "Keep it under 5000 characters."),
  visibleToStudent: z.boolean(),
});
type NotesFormData = z.infer<typeof NotesSchema>;

interface MentorSessionNotesProps {
  sessionId: string;
  notes: SessionNotes | null;
  readOnly: boolean;
}

export function MentorSessionNotes({ sessionId, notes, readOnly }: MentorSessionNotesProps) {
  const router = useRouter();
  const form = useForm<NotesFormData>({
    resolver: zodResolver(NotesSchema),
    defaultValues: {
      body: notes?.body ?? "",
      visibleToStudent: notes?.visible_to_student ?? false,
    },
  });

  if (readOnly) {
    if (!notes) return null;
    return (
      <section className="flex flex-col gap-3">
        <h2 className="section-title">Mentor notes</h2>
        <div className="prose-content whitespace-pre-line rounded-lg border border-border bg-card p-4">
          {notes.body}
        </div>
      </section>
    );
  }

  async function onSubmit(data: NotesFormData) {
    const result = await saveSessionNotesAction(sessionId, data.body, data.visibleToStudent);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Notes saved.");
    router.refresh();
  }

  return (
    <section className="flex flex-col gap-3">
      <h2 className="section-title">Mentor notes</h2>
      <Form {...form}>
        <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
          <FormField
            control={form.control}
            name="body"
            render={({ field }) => (
              <FormItem>
                <FormControl>
                  <Textarea placeholder="Private write-up of the session…" rows={5} {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormField
            control={form.control}
            name="visibleToStudent"
            render={({ field }) => (
              <FormItem className="flex flex-row items-center justify-between gap-3 rounded-lg border border-border p-4">
                <FormLabel className="cursor-pointer">Visible to student</FormLabel>
                <FormControl>
                  <Switch checked={field.value} onCheckedChange={field.onChange} />
                </FormControl>
              </FormItem>
            )}
          />
          <Button className="w-fit" disabled={form.formState.isSubmitting} type="submit">
            {form.formState.isSubmitting ? "Saving…" : "Save notes"}
          </Button>
        </form>
      </Form>
    </section>
  );
}
