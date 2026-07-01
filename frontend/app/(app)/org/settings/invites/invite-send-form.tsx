"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ORG_ROLE_OPTIONS } from "@/lib/constants";

const Schema = z.object({
  emailsRaw: z.string().min(1, "Enter at least one email address"),
  role: z.string().min(1, "Select a role"),
});

type FormData = z.infer<typeof Schema>;

function parseEmails(raw: string): string[] {
  return raw
    .split(/[\n,;]+/)
    .map((e) => e.trim().toLowerCase())
    .filter((e) => e.length > 0 && e.includes("@"));
}

interface InviteSendFormProps {
  onSend: (emails: string[], role: string) => Promise<void>;
}

export function InviteSendForm({ onSend }: InviteSendFormProps) {
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { emailsRaw: "", role: "student" },
  });

  async function onSubmit(data: FormData) {
    const emails = parseEmails(data.emailsRaw);
    if (emails.length === 0) {
      form.setError("emailsRaw", { message: "No valid email addresses found" });
      return;
    }
    await onSend(emails, data.role);
    form.reset();
  }

  return (
    <section className="card-base p-6">
      <h2 className="section-title mb-4">Batch Invite</h2>
      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="form-stack">
          <FormField
            control={form.control}
            name="emailsRaw"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Email addresses</FormLabel>
                <FormControl>
                  <Textarea
                    {...field}
                    placeholder={
                      "alice@example.com\nbob@example.com\n\nor paste CSV: alice@x.com, bob@x.com"
                    }
                    rows={5}
                    className="font-mono text-sm resize-y"
                  />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <div className="stack-md items-end">
            <FormField
              control={form.control}
              name="role"
              render={({ field }) => (
                <FormItem className="w-full sm:w-44">
                  <FormLabel>Role</FormLabel>
                  <Select value={field.value} onValueChange={field.onChange}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select a role" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {ORG_ROLE_OPTIONS.map((opt) => (
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

            <Button
              type="submit"
              disabled={form.formState.isSubmitting}
              className="w-full sm:w-auto"
            >
              {form.formState.isSubmitting ? "Sending…" : "Send Invites"}
            </Button>
          </div>
        </form>
      </Form>
    </section>
  );
}
