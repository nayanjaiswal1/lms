"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { UserPlus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { inviteAction } from "@/lib/server/calendar";
import { ATTENDEE_ROLE_OPTIONS } from "@/lib/calendar/types";
import type { AttendeeRole, EventInvite } from "@/lib/calendar/types";

// An external invite can only ever grant 'editor' or 'viewer' — the backend
// rejects 'owner' here (IsValidInviteRole in backend/internal/calendar/models.go).
const INVITE_ROLE_OPTIONS = ATTENDEE_ROLE_OPTIONS.filter((opt) => opt.value !== "owner");

const InviteSchema = z.object({
  email: z.string().email("Enter a valid email."),
  role: z.enum(["editor", "viewer"]),
});
type InviteFormData = z.infer<typeof InviteSchema>;

interface InviteFormProps {
  eventId: string;
  onInvited: (invite: EventInvite) => void;
}

export function InviteForm({ eventId, onInvited }: InviteFormProps) {
  const form = useForm<InviteFormData>({
    resolver: zodResolver(InviteSchema),
    defaultValues: { email: "", role: "viewer" },
  });

  async function onSubmit(data: InviteFormData) {
    const result = await inviteAction(eventId, data.email, data.role as AttendeeRole);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not send invite.");
      return;
    }
    toast.success(`Invited ${data.email}.`);
    onInvited(result.data.invite);
    form.reset({ email: "", role: "viewer" });
  }

  return (
    <Form {...form}>
      <form className="flex items-end gap-2" onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem className="flex-1">
              <FormLabel className="sr-only">Email</FormLabel>
              <FormControl>
                <Input placeholder="Invite by email…" type="email" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="role"
          render={({ field }) => (
            <FormItem className="w-full sm:w-32">
              <FormLabel className="sr-only">Role</FormLabel>
              <Select defaultValue={field.value} onValueChange={field.onChange}>
                <FormControl>
                  <SelectTrigger aria-label="Attendee role">
                    <SelectValue />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  {INVITE_ROLE_OPTIONS.map((opt) => (
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
        <Button disabled={form.formState.isSubmitting} size="icon" type="submit" variant="outline">
          <UserPlus aria-hidden className="h-4 w-4" />
          <span className="sr-only">Send invite</span>
        </Button>
      </form>
    </Form>
  );
}
