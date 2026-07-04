"use client";

import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { assignTicketAction } from "@/lib/mentoring/actions";

const AssignSchema = z.object({
  mentorId: z.string().min(1, "Select a mentor."),
});
type AssignFormData = z.infer<typeof AssignSchema>;

interface AssignTicketControlProps {
  ticketId: string;
  mentors: { user_id: string; name: string }[];
}

export function AssignTicketControl({ ticketId, mentors }: AssignTicketControlProps) {
  const router = useRouter();
  const form = useForm<AssignFormData>({
    resolver: zodResolver(AssignSchema),
    defaultValues: { mentorId: "" },
  });

  async function onSubmit(data: AssignFormData) {
    const result = await assignTicketAction(ticketId, data.mentorId);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Ticket assigned.");
    router.refresh();
  }

  return (
    <Form {...form}>
      <form className="flex items-center gap-2" onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="mentorId"
          render={({ field }) => (
            <FormItem>
              <FormControl>
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger aria-label="Assign to mentor" className="w-full sm:w-40">
                    <SelectValue placeholder="Assign to…" />
                  </SelectTrigger>
                  <SelectContent>
                    {mentors.map((m) => (
                      <SelectItem key={m.user_id} value={m.user_id}>{m.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button disabled={form.formState.isSubmitting} size="sm" type="submit">
          Assign
        </Button>
      </form>
    </Form>
  );
}
